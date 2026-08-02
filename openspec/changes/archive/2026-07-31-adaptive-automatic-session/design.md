## Context

`diagnostic-session-model` 已把所有可持久化事件收口到 `ArgosManager.dispatch`，并以同步运行时状态加存储 `_opChain` 保证 session、sequence 和 record 的顺序。目前 automatic 模式仅在首次 init 创建一个 session；App 退后台只 flush，直到显式 stop 或下次进程恢复前都不会产生新边界。这保证兼容，却会让一次长进程中的多轮复现、长时间后台前后以及用户/租户切换共享同一个 sessionId。

本变更需要跨公共配置、session endReason、manager lifecycle、dispatch 和存储队列，但必须继续支持 Dart >= 2.17 / Flutter >= 3.0，不引入 sealed class、后台任务或第三方依赖。现有持久化信封已经把 endReason 编码为字符串并容错未知值，因此可在不提升 schemaVersion 的情况下扩展结束原因。

## Goals / Non-Goals

**Goals:**

- 保持默认 automatic 的现有进程级行为和所有 manual/显式会话语义。
- 提供 opt-in adaptive 策略，按长时间后台、最大时长和宿主上下文变化形成稳定边界。
- 保证触发边界的事件只进入新会话，listener 与 storage 获得一致 metadata。
- 不依赖后台定时器，并让时间与 lifecycle 测试可使用注入时钟确定性执行。
- 明确区分自动管理会话与显式创建会话，避免配置策略静默接管调用方控制权。

**Non-Goals:**

- 不实现事故触发式 Session、异常前置事件环形缓冲或异常后的观察窗口。
- 不按 route、单个请求、点击或导航切分，也不采集新的用户行为数据。
- 不改变 manual 模式、`captureEnabled` 映射或显式 stop 后保持 idle 的行为。
- 不保证后台超时点到恢复点之间执行代码或实时落盘；边界在下一次可执行 lifecycle/dispatch 检查时兑现。
- 不升级存储信封 schemaVersion，也不改变 maxSessions/per-kind retention。

## Decisions

### D1：使用策略值对象，并以 process 作为默认策略

新增 `ArgosAutomaticSessionStrategy { process, adaptive }` 和不可变 `ArgosAutomaticSessionPolicy`。policy 包含 strategy、可空 `backgroundTimeout`、可空 `maxDuration` 与可空同步 `ArgosSessionContext Function()`；adaptive 工厂提供 2 分钟后台超时和 30 分钟最大时长的默认值，调用方可用 null 单独关闭某条边界。非空 Duration 必须大于零。

`ArgosConfig.automaticSessionPolicy` 默认 `process`。没有配置的现有应用因此逐字保持当前生命周期语义；adaptive 必须由宿主主动选择。备选方案是把 adaptive 直接设为 automatic 新默认值，但这会在小版本升级后改变 session 数量和诊断分组，故不采用。

### D2：运行时显式标记 automatic-managed，而不是从 sessionMode 反推

Manager 为 active session 保存 `_activeSessionIsAutomatic` 与创建时的 policy 快照。只有首次 automatic init 和内部 rollover 创建的 session 标记为 true；公共 `startSession()` 创建的会话即使当前 config.sessionMode 是 automatic，也标记为 false。重复 init 不改变标记或 policy 快照，显式 stop 清除标记且不会由后续 dispatch 隐式重启。

备选方案是每次检查当前 `config.sessionMode`，但调用方重复 init 或运行时替换 config 后会让既有会话突然被策略接管，不可预测。

### D3：后台边界在 lifecycle 恢复时兑现，不运行后台 Timer

adaptive recording 会话进入 paused/detached 时记录 `_backgroundedAt` 并沿用现有 flush；inactive 不单独建立边界。resumed 时比较实际经过时间：小于 backgroundTimeout 则清除候选并继续原 session；达到阈值则 rollover。旧 endedAt 使用 `max(backgroundedAt + timeout, lastEventAt)`，新 startedAt 使用实际恢复时间，因此既不把旧会话结束时间写到已有事件之前，也不会声称 App 在后台某一时刻真实执行过结束逻辑。

显式 session pause 优先：若 `sessionState == paused`，lifecycle 只 flush/清理候选而不 rollover，`resumeSession()` 仍恢复同一 ID。进程在后台被杀时继续由现有 interrupted recovery 负责。

备选方案是在退后台时启动 Timer，但 Flutter isolate 可能被立即挂起，Timer 无法提供可靠边界，还会使平台差异进入公开语义。

### D4：最大时长由下一事件惰性检查，显式暂停时间不计入期限

Manager 在 automatic-managed adaptive session 创建时建立最大时长 deadline。每条原本可接受的事件在 sequence 分配前检查 deadline；达到期限则先 rollover，再把事件作为新 session 的 sequence 1。显式 pause 记录暂停起点，resume 时把 deadline 向后平移暂停时长，避免 pause/resume 本身导致下一事件立即换 ID。短暂 App 后台仍属于诊断会话时长，长后台由更具体的 backgroundTimeout 边界处理。

不使用周期轮询，因此没有事件时不会仅为时间到点而创建空的新 session。旧 endedAt 使用 deadline 与 lastEventAt 的较大值，新 startedAt 使用触发事件时间。

### D5：上下文 fingerprint 只比较、不持久化，attributes 才进入 Session

新增不可变 `ArgosSessionContext`，包含 required 的非空 opaque `fingerprint` 与字符串 attributes。可选 provider 在 automatic-managed 会话创建时和 recording dispatch 前同步调用。fingerprint 变化代表用户、租户、后端环境等宿主定义上下文变化；旧 session 以 contextChanged 结束，新 session 复制新 attributes。fingerprint 本身不自动写入 attributes 或日志，避免把账号标识意外持久化；若宿主希望展示，必须显式提供已脱敏 attribute。

provider 抛错时捕获并通过既有诊断日志报告，保留最近一次有效上下文并继续本次事件。routeName 不参与 fingerprint。相比让 SDK 猜测登录或导航状态，宿主 provider 更准确，也不需要新增业务耦合。

### D6：统一的同步 rollover 决策先于 metadata 分配

新增内部 `_rollAutomaticSession(reason, boundaryAt, nextContext)`：同步构造 completed old session、激活 new session、重置 `_nextSequence`、更新时间 deadline/context 快照，然后按 complete(old) → begin(new) 的顺序调用存储队列 API。dispatch 随后分配新 metadata 并 append，因此触发事件不可能写入旧 session。该路径不调用公开 `stopSession()`，避免临时 idle、逐次 flush 和 automatic-managed 标记丢失。

策略检查顺序固定为 contextChanged → maxDuration；backgroundTimeout 在 resumed lifecycle 先独立兑现并创建已采样当前上下文的新会话。因此一次检查只执行一个 rollover。Dart 单 isolate 中同步状态切换不可交错，持久化仍由现有 `_opChain` 串行化；不新增 mutex。

### D7：结束原因扩展但存储 schema 不迁移

`ArgosSessionEndReason` 增加 backgroundTimeout、maxDuration、contextChanged。显式 stop 仍为 completed，进程恢复仍为 interrupted。序列化继续写 enum 字符串，反序列化继续把未知字符串降级为 null，因此旧记录和未来值保持容错；信封结构没有变化，不提升 schemaVersion。

### D8：可测试时钟与 lifecycle hook 只作为内部 seam

时间判断通过 manager 内部可替换的 `now` seam，测试可精确推进后台时长、deadline 和同一时刻的事件；生产默认使用 `DateTime.now()`。沿用或补充 testing-only lifecycle/dispatch hooks 验证状态机，不把 Clock package 加入公开依赖。

## Risks / Trade-offs

- [adaptive 是 opt-in，现有用户不会自动获得更好的分段] → README 给出推荐配置和迁移示例，后续大版本可根据真实数据评估默认值。
- [系统时钟在后台被用户修改会使 elapsed 异常] → 对负时长钳制为零，endedAt 永不早于 startedAt/lastEventAt；不为这一边界引入平台单调时钟依赖。
- [context provider 位于 dispatch 热路径] → 要求同步且轻量，只比较字符串；异常被隔离，文档提示宿主缓存业务上下文而非执行 I/O。
- [rollover 内存状态先于异步存储完成] → complete、begin、append 共用现有串行队列，失败沿用存储错误报告；listener 仍获得一致的新 session metadata。
- [长后台恢复立即创建的新会话可能最终没有事件] → 保持 recording/captureEnabled 与现有 automatic 语义一致；惰性建会话需要新增 armed 状态，留给未来独立设计。
- [maxDuration 与 contextChanged 同时成立只能保存一个原因] → 固定优先记录 contextChanged，行为可测试且两个边界都通过同一次 rollover 得到满足。

## Migration Plan

1. 增加策略、上下文模型和新 endReason，保持所有新增构造参数可选且默认 process。
2. 在 manager 引入 automatic-managed 标志、policy/context/deadline 快照与可测试时钟。
3. 实现统一 rollover，再接入 dispatch 的 context/maxDuration 检查。
4. 接入 lifecycle 后台时间记录和 resumed 超时判断，复用现有 flush。
5. 增加模型、状态机、存储顺序、生命周期与兼容性测试，并更新文档/example。
6. 发布时不迁移历史数据；回滚旧版本时新 endReason 会按旧版 tolerant parser 降级为 null，session 与 records 仍可读取。

## Open Questions

- adaptive 的 2 分钟后台超时和 30 分钟最大时长是否适合作为推荐值，需要在 example 手工复现与真实诊断包大小上验证。
- 后续 incident-driven 提案是否复用 `ArgosSessionContext` 和内部 rollover primitive，还是引入独立的 armed/prebuffer controller。
