## Context

Argos 当前有两条不同的数据流：HTTP/原生 HTTP 在 monitor 内检查 `captureEnabled` 并直接写 `ArgosPacketStorage`，crash/jank/resource 则调用 `ArgosManager.dispatch`，后者只以 `enableStorage` 决定是否落盘。结果是列表上的“暂停”只可靠暂停网络记录，其他 APM 事件仍可能继续回调和存储。

持久化层目前把全部 `ArgosPacketRecord` 编码为单个 JSON List，通过可插拔 `ArgosStorageAdapter` 串行读写，并按 kind 做全局配额。记录具有时间戳和 routeName，但没有一次诊断过程的边界；现有 id 多数直接来自毫秒时间戳，同毫秒事件缺少可靠唯一性和稳定顺序。App 后台会触发 flush，但进程被杀、热重启或 crash 后无法判断一段记录是否属于未正常结束的复现过程。

该变更跨越公共模型、manager 状态、所有 monitor、存储格式和聚合查询。包仍承诺 Dart >= 2.17 / Flutter >= 3.0，因此不能依赖 Dart 3 sealed class，并应避免为 UUID 或状态管理引入新依赖。

## Goals / Non-Goals

**Goals:**

- 用一个明确、可持久化且可恢复的 session 表示一次诊断录制。
- 让所有事件类型共享同一个录制门控、sessionId 和稳定顺序。
- 保留 `captureEnabled`、`ArgosPacketRecord` 和现有全局列表 API 的源码兼容性。
- 无损读取既有记录，并提供可回滚的存储迁移路径。
- 以 session 为保留边界，显式标识任何被裁剪的活动会话。
- 保证 session 与 records 在现有串行队列上的顺序一致性。

**Non-Goals:**

- 不增加 session 时间线页面或改变现有列表的一级信息架构。
- 不记录导航 breadcrumb、点击、输入或屏幕内容。
- 不提供脱敏、分享、HAR/诊断包导出或请求回放。
- 不增加异常根因推断、DevTools 或 OpenTelemetry 集成。
- 不重构所有事件 payload 为 sealed hierarchy，也不改变既有 HTTP/APM 详情模型。
- 不把当前仅用于实时 listener 的高频 FPS 快照持久化为 session records；session 首版覆盖已有可持久化事件类型。

## Decisions

### D1：Session 是有边界的录制，不等同于 App 生命周期或 trace

Session 运行时状态为 idle、recording、paused；持久化结束原因为 completed 或 interrupted。App 进后台只 flush，不结束 session；下次进程启动时，任何没有 endedAt 的旧 session 都会以 lastEventAt（无事件时用 startedAt）结束为 interrupted。Crash 只是一条事件，因为 Flutter 错误被捕获后进程可能继续运行。

备选方案是“每次 App 启动固定一个 session”，实现简单，但无法表达用户暂停、手动复现和同一次进程中的多轮诊断，因此不采用。

### D2：默认 automatic，manual 显式开始

`ArgosConfig.sessionMode` 默认 automatic。为保持现有行为，automatic 仅在 `enableStorage == true` 时随首次 init 自动录制；manual 无论是否配置存储都等待 startSession。显式 startSession 在没有 adapter 时仍可创建内存会话并驱动 listener，因此 enableStorage 只决定持久化，不决定显式会话能否存在。

重复 init 不创建第二个活动会话。重复 start 在 recording 时幂等返回当前会话，在 paused 时恢复同一会话。调用方必须先 stop 当前会话，才能创建另一会话，避免静默替换造成事件归属不清。

### D3：Manager 是唯一录制门控和元数据分配点

所有 monitor 保留各自的捕获与 payload 构建职责，但最终都调用 `ArgosManager.dispatch(model, record:)`。dispatch 的顺序为：

1. 检查 sessionState；非 recording 立即丢弃，不调用 listener、不写存储、不消耗 sequence。
2. 从 session controller 同步分配下一 sequence，并生成不可变事件元数据。
3. 把相同元数据写入 `ArgosBaseModel` 和 `ArgosPacketRecord` 副本。
4. 调用 listener。
5. enableStorage 为 true 时，把 record 排入存储串行队列。

事件自己的资格判断（capability 是否启用、HTTP host 规则、错误去重）仍在进入 dispatch 前完成，不由 session controller 改变。`ArgosNativeCapture` 也必须进入同一 dispatch，而不是直接 append。

存储 adapter 在 `ArgosManager.init` 中只配置一次，再初始化 monitors，避免多个 capability 重复 setAdapter 和重置缓存。

### D4：最小扩展现有模型，不引入第二套事件 hierarchy

新增 `ArgosDiagnosticSession`、`ArgosSessionMode`、`ArgosSessionState`、`ArgosSessionEndReason` 和不可变 `ArgosEventMetadata`。`ArgosBaseModel` 增加可空 eventMetadata，供 listener 读取 sessionId、sequence 和 id；`ArgosPacketRecord` 增加可空 sessionId 与默认 0 的 sequence，并复用现有 id 作为事件 ID。

新 session id 由 Unix 微秒时间、进程内单调计数和安全随机片段组合生成，不新增 UUID package。新事件 id 直接由 `<sessionId>:<sequence>` 派生，因此在 sessionId 唯一的前提下天然唯一。平台侧传入的原始网络 id 只作为 payload 来源，最终持久化 id 由 manager 规范化。旧记录 id 原样保留。

备选方案是创建通用 `ArgosEventEnvelope<Map<String, dynamic>>` 并替换 `ArgosPacketRecord`。它更纯粹，但会同时重写所有详情 UI 和公开构造器，超出本 change 的目标。

### D5：运行时状态立即变化，持久化变化排入同一队列

Session controller 保存在 ArgosManager 内，使 start/pause/resume 和 `captureEnabled` getter 能同步反映状态。对应 session 元数据变更随后按调用顺序排入 `ArgosPacketStorage`。这样无需把现有同步 `init()` 改为 async，也不会在自动初始化和第一条事件之间出现无 activeSession 的窗口。

存储首先 hydrate/recover 旧信封，再落入本次自动 session；由于 beginSession 与 appendRecord 共用 `_opChain`，第一条事件不会跑到 session 创建之前。需要等待持久化保证的 stop、clear 和 flush API 返回 Future。

### D6：captureEnabled 成为 sessionState 的兼容视图

getter 返回 `sessionState == recording`。setter false 映射 pause；setter true 在 paused 时 resume、在 idle 时 start。现有列表按钮无需立即改 API，但其行为会从“只暂停网络”修正为“暂停所有 Argos 事件”。新代码和测试优先使用显式 session API。

不把 captureEnabled 作为独立可变 bool 保存，避免它与 sessionState 分叉。

### D7：使用新 key 的版本化信封，保留 legacy key 以便回滚

新主键为 `argos_diagnostic_store_v1`，内容形状为：

```json
{
  "schemaVersion": 1,
  "sessions": [],
  "records": []
}
```

hydrate 优先读取新 key；新 key 不存在时读取 legacy `argos_packet_records` List，把可解析元素作为 sessionId null、sequence 0 的历史记录。首次变更/flush 把它们与新 session 一起写入新 key，但不删除或覆盖 legacy key。这样降级到旧版包时最多看到迁移前的旧快照，不会因旧解码器遇到 Map 而丢失全部记录。

`clear()` 是例外：用户明确要求删除全部数据，因此同时清除新旧 key。解析到未知 schemaVersion 时不猜测格式：记录一次诊断错误并返回空的只读缓存，避免用当前写入覆盖未来版本数据。

### D8：Session-aware retention 保留完整关系

新增 `maxSessions`，默认 5。超过上限时删除 startedAt 最早的 completed/interrupted session 及其全部 records，永不整体删除 activeSession。若暂时没有可淘汰的已结束 session，允许短暂超过 maxSessions。

现有 `maxPacketRecords` 和 `resourceMaxRecords` 改为“每个 session、每种 kind”的上限，保留开发者熟悉的配置语义。活动 session 内发生裁剪时设置 truncated=true；已结束 session 不再局部裁剪。sessionId null 的 legacy records 作为独立历史桶沿用旧的 per-kind 配额，不计入 maxSessions。

备选方案是继续做全局 per-kind 淘汰，但它会让一个已结束 session 在没有任何标志的情况下逐渐残缺，无法成为可信诊断单元。

### D9：查询同时保留兼容全局视图和 session 视图

`getAllAsync()` 继续返回所有 records 的 startTimestamp 倒序合并列表，现有 UI 无需在本 change 中改造成 session 页面。新增 session 列表和按 sessionId 查询 records 的接口；后者以 sequence 升序返回，作为未来时间线的稳定数据源。资源聚合在 sessionId 变化或空/非空切换处强制断开。

### D10：Crash 写入采用 best-effort 强制刷新

Crash monitor 不能 await async storage，否则可能改变 Flutter/PlatformDispatcher handler 时序。因此 dispatch 返回或暴露该记录的 append Future，crash 路径在 append 完成后无等待地链式调用 flush，并吞掉/报告存储错误，随后照常调用宿主旧 handler。这不是进程崩溃下的绝对持久化保证，但显著缩小默认 5 秒合并周期造成的丢失窗口。

## Risks / Trade-offs

- [新信封继续整表 JSON 编码，session 增多会提高编码成本] → maxSessions 与 per-kind 配额共同限制数据规模，继续使用合并落盘；更大规模存储留给后续 adapter/索引 change。
- [captureEnabled 开始约束 crash/jank/resource，行为与当前版本不同] → 这是统一录制语义的有意修正；在 CHANGELOG 和 README 明确说明暂停现在适用于所有事件。
- [legacy key 为回滚保留会暂时占用额外空间] → 旧记录已有严格配额，空间上界有限；clear 同时删除两个 key，后续大版本可单独清理 legacy 数据。
- [setter 触发的异步持久化失败无法同步抛给调用方] → 运行时状态优先一致，存储层记录错误；需要强保证的调用方使用返回 Future 的 stop/flush/clear API。
- [进程在 session metadata 或 crash flush 真正落盘前被系统强杀] → 所有操作共享队列、后台主动 flush、crash best-effort flush；下次恢复仍把已落盘的开放 session 标为 interrupted。
- [sessionId/sequence 加入公开模型会影响手写测试 fixture] → 新字段提供可空/默认值，旧构造器和旧 JSON 保持可用，并新增 migration fixtures。
- [现有 routeName 由宿主主动维护，session 仍不等于导航轨迹] → 本 change 只记录事件发生时的路由快照；breadcrumb 作为独立后续 capability。

## Migration Plan

1. 增加 session、event metadata 和配置枚举，所有新增字段保持旧构造兼容。
2. 将存储缓存升级为内存信封，同时实现新 key 优先、legacy key 回退的双读逻辑。
3. 实现 session controller 与队列化 session 操作；在 manager 初始化时只绑定一次 adapter。
4. 先迁移 crash/jank/resource 到统一门控，再迁移 Dart HTTP 和 native HTTP，确保没有直接 append 路径残留。
5. 增加 session-aware 查询、淘汰、clear 和 crash flush。
6. 更新资源聚合边界、README/CHANGELOG，并通过旧 JSON fixture、状态机、并发和所有事件类型测试验证。

回滚时旧版本继续读取未被修改的 `argos_packet_records`；新版数据留在 `argos_diagnostic_store_v1`，不会被旧版本误解析。重新升级后可继续读取新版信封。若新版信封出现不可恢复问题，可清除新 key 后从 legacy 快照重新迁移；该操作会丢失升级后新产生的 session，必须由调用方明确触发，不能自动执行。

## Open Questions

- 暂停和恢复是否需要在未来时间线中显示显式 gap marker？本 change 只保留状态语义，不创建 marker record。
- maxSessions 默认值 5 是否适合真实使用，应在发布后根据诊断包大小和用户反馈调整；配置项允许立即覆盖默认值。
