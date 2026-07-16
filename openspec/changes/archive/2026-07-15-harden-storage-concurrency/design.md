## Context

`ArgosPacketStorage` 是一个单例，通过可插拔的 `ArgosStorageAdapter`（`read`/`write`/`clear` 均为 `Future`）把一条 JSON 记录列表存于单个 key 下。当前并发模型：

- 写入经 `_writeChain`（`Future` 链）串行化，保证 append 之间无丢更新。
- 但 `clear()` 直接 `_adapter.clear()`、`getAllAsync()` 直接 `_readList()` —— **都不在 `_writeChain` 上**。
- `_writeAsync` 每次都 `await _readList()`（读 adapter + `jsonDecode` 整表）→ `add` → `_trimKind` → `jsonEncode` 整表 → `write`。

三处调用点（`argos_manager.dart` 的 `dispatch`、`argos_http_monitor.dart`、`native/argos_native_capture.dart`）以 `append`/`appendRecord` 写入；`ArgosPacketListPage` 以 `getAllAsync` 读、以 `clear` 清空。资源监控每 2 秒经 `dispatch` 写一条。

前一个变更（per-kind-storage-quota）已让 `append`/`appendRecord` 返回其写入 `Future`，供测试等待具体写入。本次在此基础上把「串行化」从「仅写入」扩展到「全部操作」，并引入内存缓存去掉全表读解码。

## Goals / Non-Goals

**Goals:**
- 所有变更与读取操作按发起顺序全序执行：`clear` 与写入有序，读取观察到此前操作的结果。
- 消除每次写入的全表读取 + 全量解码。
- **把 UI isolate 上唯一的同步 CPU 成本(`jsonEncode`)频率降到最低**,不阻塞事件循环导致掉帧;读取路径永不等待磁盘。
- 数据语义、按 kind 分区淘汰、大 Body 截断、路由字段等既有行为保持不变。
- 公开 API 签名兼容，调用点零改动。

**Non-Goals:**
- 不把 `jsonEncode`/`jsonDecode` 搬到后台 isolate——对小而频繁的写入,`Isolate.run` 的启动(约 1-2ms)与跨 isolate 数据拷贝常大于 encode 本身,得不偿失;合并落盘已把同步 encode 频率降到足够低。
- 不改存储介质、adapter 接口、数据模型。
- 不支持「同一进程内多个 adapter 并行使用」——单例单 adapter，`setAdapter` 用于 init 期设置或测试替换。

## Decisions

### 决策一：单条串行操作队列覆盖 append / clear / getAll

把 `_writeChain` 泛化为 `_opChain`：每个操作（写、清、读）都是链上的一个任务，`_opChain = _opChain.then((_) => task())`。这样：

- **clear 不再绕过队列**：clear 作为链上任务执行，与其前后的写入构成确定顺序——发起于 clear 之前的写入会被清掉，发起于 clear 之后的写入正常保留，不再有「清空被撤销」或「写入丢失」。
- **读取观察全序**：`getAllAsync` 也入链，返回时已反映此前入链的全部操作。这对 Inspector 是期望行为（读到最新），代价是读会等待此前排队的写入完成——队列中的写入是有限的，不构成问题。

前一个变更曾试过「让 `getAllAsync` 直接 `await _writeChain`」，因在途写入会以**执行时**的 `_adapter` 重新读写、在 adapter 被替换时覆盖数据而回退。本设计不同：数据源是内存缓存（决策二），adapter 只在水合/持久化/清空时按序被触碰，不存在「读触发在途写重放到新 adapter」的路径。

### 决策二：内存缓存作为唯一数据源，惰性水合一次

维护 `List<Map<String, dynamic>>? _cache`：

- 首次需要数据时（首个入链操作）从 adapter `read + jsonDecode` **一次**，填充 `_cache`。
- 之后 append 直接在 `_cache` 上 `add` + `_trimKind`，`getAllAsync` 从 `_cache` 映射为 `ArgosPacketRecord` 并排序，均**不再读 adapter、不再解码**。
- 每次变更后把 `_cache` `jsonEncode` 写回 adapter（保持持久化，不丢数据）。
- `clear` 置 `_cache = []` 并 `adapter.clear()`。

收益：每次 append 省掉一次 adapter 读 + 一次整表 `jsonDecode`；`getAllAsync` 省掉一次读 + 一次整表解码。资源采样每 2s 不再反复解码约数百条记录。

### 决策三：`setAdapter` 使缓存失效

切换 adapter 时置 `_cache = null`，下次入链操作重新从新 adapter 水合。保证缓存与当前 adapter 一致，消除「旧缓存配新 adapter」的隐患，也让测试「直接 `adapter.write` 预置数据 + `setAdapter`」的用法自然生效（首次读会从新 adapter 水合出预置数据）。

### 决策四:合并落盘,把 UI isolate 上的同步 encode 频率降到最低

先厘清「阻塞」:Dart 单 isolate,`async`/`await` 是事件循环上的协作式并发,`await` 只让出、不占线程;串行操作队列排队的任务只是「尚未调度」,不阻塞任何线程。真正会占用 UI 线程的只有**同步 CPU**——`jsonEncode`/`jsonDecode`,它们跑到完成才让出,`await` 搬不走。决策二的内存缓存已消掉每次读写的整表**解码**;剩下的唯一同步成本是写入前的整表**编码**。

因此把「编码 + 落盘」与「内存变更」解耦:

- append/clear **同步**更新 `_cache`(读永远拿到最新,与落盘时机无关),然后标记 dirty 并**调度**一次延迟 flush,而非立即 encode+write。
- flush 由「首次 dirty 起算的节流定时器」触发:变脏且当前无待定 flush 时,启动一个 `persistInterval` 定时器;定时器到点时把当前 `_cache` `jsonEncode` 一次并写回 adapter,清 dirty。这样把「每次写入一次 encode」摊薄为「每 `persistInterval` 至多一次 encode」。
- **强制 flush 时机**:①App 退到后台/暂停(`AppLifecycleState.paused`/`inactive`/`detached`)——OS 最可能在此后杀进程,退后台即落盘把丢数据窗口收敛;②`clear()`——用户主动且低频,立即落盘;③`flush()` 被显式调用时。
- flush 本身作为一个任务经 `_opChain` 串行执行,与其他操作有序,不与写入/清空竞态。
- `persistInterval` 经 `ArgosConfig.storagePersistInterval` 配置(默认如 5s),`Duration.zero` 表示「每次写入即落盘」的完全持久化模式(退化回决策前语义,不丢数据)。

生命周期观察:`ArgosPacketStorage` 只暴露 `Future<void> flush()`,由 `ArgosManager` 在 `init` 时注册一个 `WidgetsBindingObserver`,在 `paused`/`detached` 回调里调用 `flush()`。存储层因此不反向依赖 widgets 绑定,便于单测(可直接调 `flush()` 验证)。

**读取不受影响**:`getAllAsync` 永远从 `_cache` 返回,合并落盘只推迟**磁盘**写,不推迟**读**看到的数据——顺序一致性(决策一)仍成立,因为一致性是逻辑序,由 `_cache` 的同步更新保证,与磁盘 flush 时机无关。

### 决策五：持久化失败不破坏内存一致性

`adapter.write` 抛错时（沿用现有 `try/catch + debugPrint`）：内存 `_cache` 已经是最新，仅落盘失败。下次成功写入会把完整 `_cache` 落盘，自愈。链不因单次失败而中断（任务体内吞异常，`_opChain` 保持可用）。

## Risks / Trade-offs

- **[合并落盘引入崩溃丢数据窗口]** → 窗口有界:最长 `persistInterval`,或到下次退后台/`clear`,以先到者为准。App 通常先被切到后台再被杀,退后台强制 flush 覆盖了最常见路径;仅硬崩溃(如 SIGSEGV)会丢失窗口内记录。`persistInterval` 可配,`Duration.zero` 即完全持久化。对调试期 Inspector 可接受,且已在 proposal 与本文档写明。
- **[内存缓存与磁盘短暂不一致（写盘失败时）]** → 内存始终是最新的事实来源；下次成功写入整表落盘即自愈。对调试期 Inspector 可接受。
- **[读取入队后需等待此前排队的写入]** → 队列中写入有限且快（内存 add + 一次落盘），等待可忽略；换来的是读写全序一致，值得。
- **[内存常驻整个记录列表]** → 记录数受 per-kind 配额上限约束（最坏数百条 JSON），常驻内存量可控；本就要在读时全量加载。
- **[`setAdapter` 在有在途操作时切换]** → 属 init 期或测试用法；缓存失效点明确，在途操作在其自身任务内使用当时的 adapter，语义可预期。以单元测试覆盖「预置 + setAdapter + 读」路径。
- **[重构触及写入热路径，回归面大]** → 既有存储配额与列表页测试全部保持通过为底线；新增并发/顺序一致性用例（clear-vs-write、读观察全序、水合一次、setAdapter 失效）。
