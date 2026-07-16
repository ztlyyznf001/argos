## Why

`ArgosPacketStorage` 的并发模型只覆盖了一半：写入经 `_writeChain` 串行化，但 `clear()` 与 `getAllAsync()` 都绕过了这条链，直接读写 adapter。由此产生真实的竞态与浪费：

1. **`clear()` 与写入无序，会导致清空被撤销或写入丢失。** `clear()` 直接调用 `_adapter.clear()`，不在写链上。当用户在一条资源采样写入排队/在途时点「清空」，两者顺序未定义：可能出现「append 读到 `[A]` → clear 清空 → append 的写入把 `[A, new]` 落盘」，即被清空的数据复活；反向则丢失一次写入。这是一个明确的正确性缺陷。
2. **`getAllAsync()` 读取不经串行化，可能读到写入在途的中间态。** 读直接走 `_readList`，与在途写入无互斥，读到的可能是某次写入提交前的旧状态。
3. **每次写入都全表读取 + 全量解码 + 全量编码 + 全量写回。** `_writeAsync` 对每一条 append（含每 2 秒一次的资源采样）都 `_readList → jsonDecode`（当前最多约 650 条）→ add → trim → `jsonEncode` → write。资源采样会让整个存储被反复解码，是明显的写放大与 CPU 浪费。

## What Changes

- **统一串行化：所有变更与读取操作（append / clear / getAll）经同一条串行操作队列执行**，保证全序（total order）。`clear()` 不再绕过队列，与写入按发起顺序执行；`getAllAsync()` 观察到此前已发起的全部操作的结果。
- **引入内存缓存作为唯一数据源**：首次访问时从 adapter 惰性水合一次，之后 append 在内存中 add + trim，读取直接返回内存快照。消除「每次写入都全表读取并解码」的浪费。
- **合并落盘,降低 UI isolate 上的同步 `jsonEncode` 频率**：`jsonEncode`/`jsonDecode` 是同步 CPU,`await` 搬不走,是唯一会占用 UI 线程的部分。内存缓存已消掉每次读写的整表**解码**;本次进一步把**编码 + 落盘**从「每次写入」改为「合并」——内存缓存立即更新(读永远拿到最新),encode+write 按可配置周期批量执行,并在关键时机强制 flush。
- **关键时机强制 flush**:App 退到后台/暂停(`AppLifecycleState.paused`/`detached`)时、以及 `clear()` 时,立即落盘,把崩溃/被杀丢数据的窗口收敛到「上次周期 flush 或上次退后台以来」。
- **`setAdapter()` 使内存缓存失效**：切换 adapter 后下次访问重新水合,消除缓存与 adapter 不一致的隐患。
- 记录的数据语义、按 kind 分区淘汰、路由字段、大 Body 截断等既有行为**保持不变**——本次只改并发、读写路径与落盘时机,不改存了什么。

## Capabilities

### New Capabilities
<!-- 无。本次是对既有存储并发与读写行为的加固，不引入新能力。 -->

### Modified Capabilities
- `packet-storage`: 新增「存储操作串行化与顺序一致性」需求；`读取所有抓包记录` 与 `清空所有抓包记录` 增补与写入的顺序一致性场景。

## Impact

- 影响文件：`lib/storage/argos_packet_storage.dart`（核心重构：操作队列 + 内存缓存 + 串行化的 clear/read + 合并落盘 + `flush()`）；`lib/config/argos_config.dart`（新增 `storagePersistInterval`）；`lib/argos_manager.dart`（init 期配置落盘周期并注册生命周期观察者,退后台时调用 `flush()`）。
- 公开 API 签名保持兼容：`append`/`appendRecord` 仍返回 `Future<void>`,`getAllAsync`/`clear`/`setAdapter` 签名不变;新增 `Future<void> flush()`;宿主接入方式不变。
- 不改动写入调用点（`argos_http_monitor.dart`、`native/argos_native_capture.dart`）的调用形态。
- 既有测试（存储配额、列表页）应保持通过；新增并发/顺序一致性 + 合并落盘 + 强制 flush 单元测试。
- **崩溃丢数据窗口**:合并落盘引入一个有界窗口(最长为 `storagePersistInterval`,或到下次退后台/`clear`,以先到者为准)。`storagePersistInterval` 可配;设为 `Duration.zero` 即退化为「每次写入即落盘」的完全持久化模式。对调试期 Inspector,默认的有界窗口可接受。
- **Non-Goal**：把 `jsonEncode` 搬到后台 isolate——对小而频繁的写入,isolate 启动 + 数据拷贝开销常大于 encode 本身,得不偿失;合并落盘已把同步 encode 频率降到足够低。
