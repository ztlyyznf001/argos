# diagnostic-session Specification

## Purpose

定义 Argos 诊断会话的数据模型、自动与手动录制模式、生命周期控制、事件关联与稳定排序、中断恢复、查询接口及 App 生命周期行为。

## Requirements

### Requirement: 诊断会话数据模型
系统 SHALL 提供可序列化的 `ArgosDiagnosticSession`，至少包含不透明唯一 `id`、`startedAt`、可空 `endedAt`、可空 `lastEventAt`、可空 `label`、可空 `note`、字符串键值 `attributes`、可空 `endReason` 与 `truncated` 标记。时间字段 SHALL 使用 Unix 毫秒时间戳；运行时状态 SHALL 区分 `idle`、`recording` 与 `paused`，持久化后的结束原因 SHALL 至少区分显式完成 `completed`、异常中断 `interrupted`、后台超时 `backgroundTimeout`、最大时长 `maxDuration` 与诊断上下文变化 `contextChanged`。未知结束原因 SHALL 继续按可空值容错读取。

#### Scenario: 创建新会话
- **WHEN** 系统开始一次新的诊断会话
- **THEN** 会话获得非空且不与已有会话重复的 `id`、当前 `startedAt`、空 `endedAt`、`truncated == false`，并保留调用方提供的 label 与 attributes

#### Scenario: 会话序列化往返
- **WHEN** 一个包含 label、note、attributes、结束时间和任一已知结束原因的会话经过 JSON 序列化后再反序列化
- **THEN** 所有字段保持一致，未知附加字段不会导致反序列化失败

#### Scenario: 读取未来版本结束原因
- **WHEN** 持久化会话包含当前版本不认识的 endReason 字符串
- **THEN** 其他会话字段仍可读取且 endReason 降级为 null，系统不抛异常

### Requirement: 自动与手动会话模式
`ArgosConfig` SHALL 提供 `sessionMode`，支持 `automatic` 与 `manual`，默认值为 `automatic`；automatic SHALL 另由自动会话策略决定使用兼容的进程级行为还是 opt-in 的自适应分段。为保持既有初始化行为，automatic 模式 SHALL 在 `enableStorage == true` 时于首次 `ArgosManager.init()` 自动开始录制会话；manual 模式 SHALL 等待显式开始。重复调用 `init()` MUST NOT 创建重复活动会话或重新归类当前会话的策略归属。

#### Scenario: 自动模式初始化
- **WHEN** 使用默认 sessionMode、默认自动会话策略和 `enableStorage == true` 首次初始化 ArgosManager
- **THEN** 系统创建一个 process 策略管理的活动会话，运行时状态为 `recording`，`captureEnabled == true`

#### Scenario: 自适应自动模式初始化
- **WHEN** 使用 sessionMode automatic、adaptive 策略和 `enableStorage == true` 首次初始化 ArgosManager
- **THEN** 系统创建一个 adaptive 策略管理的活动会话，运行时状态为 `recording`，`captureEnabled == true`

#### Scenario: 手动模式初始化
- **WHEN** 使用 `sessionMode == manual` 初始化 ArgosManager
- **THEN** 系统不创建活动会话，运行时状态为 `idle`，直到调用方显式开始会话

#### Scenario: 自动模式保持存储关闭兼容行为
- **WHEN** 使用默认 sessionMode 和 `enableStorage == false` 初始化 ArgosManager
- **THEN** 系统不自动开始会话且 `captureEnabled == false`；调用方仍可显式开始仅存在于内存和 listener 数据流中的会话

#### Scenario: 重复初始化不重复建会话
- **WHEN** ArgosManager 已有 recording 或 paused 会话时再次调用 `init()`
- **THEN** 系统保留原 activeSession、automatic-managed 标志和策略快照，不创建第二个活动会话

### Requirement: 自动会话策略配置
`ArgosConfig` SHALL 为 automatic 模式提供 `process` 与 `adaptive` 两种自动会话策略，并以 `process` 作为默认值以保持兼容。`adaptive` 策略 SHALL 支持可空的正数 `backgroundTimeout`、可空的正数 `maxDuration` 与可空的同步诊断上下文 provider；可空时表示禁用对应边界。策略只管理由 automatic 初始化或 automatic rollover 创建的会话，显式 `startSession()` 创建的会话与 manual 模式 MUST NOT 被自动切分。

#### Scenario: 默认策略保持进程级行为
- **WHEN** 调用方没有配置自动会话策略并使用 automatic 模式初始化
- **THEN** 系统使用 process 策略，后台停留时长、会话持续时长和上下文变化均不自动替换当前 sessionId

#### Scenario: 启用自适应策略
- **WHEN** 调用方配置 adaptive 策略以及有效的后台超时和最大时长
- **THEN** 系统保留一个活动的 automatic-managed 会话，并在对应边界成立时按策略切分

#### Scenario: 无效策略时长
- **WHEN** adaptive 策略收到零或负数的非空 backgroundTimeout 或 maxDuration
- **THEN** 配置构造阶段拒绝该值，不允许形成永远立即 rollover 的运行时配置

#### Scenario: 手动创建会话不受策略管理
- **WHEN** automatic 模式已显式停止后，调用方通过 `startSession()` 创建一个会话
- **THEN** 后台超时、最大时长和上下文变化均不隐式切分该显式会话

### Requirement: 自适应最大时长边界
adaptive 策略 SHALL 在 automatic-managed 会话达到 `maxDuration` 后，于下一条原本可接受的事件分配元数据之前结束旧会话并创建新会话。旧会话 SHALL 使用 `maxDuration` 结束原因，新事件 SHALL 归属新 sessionId 且 sequence 从 1 开始；系统 MUST NOT 使用后台定时器或周期轮询维持此边界。

#### Scenario: 未达到最大时长
- **WHEN** automatic-managed 会话尚未达到 maxDuration 并收到事件
- **THEN** 事件继续使用当前 sessionId 和后续 sequence

#### Scenario: 下一事件触发时长切分
- **WHEN** automatic-managed 会话已经达到 maxDuration 并收到下一条可接受事件
- **THEN** 旧会话以 maxDuration 原因结束，系统创建不同的 sessionId，且触发检查的事件成为新会话的 sequence 1

#### Scenario: 暂停期间不进行时长切分
- **WHEN** automatic-managed 会话由调用方显式暂停且墙钟时间超过 maxDuration
- **THEN** 系统不在 paused 状态自动结束会话，显式恢复仍先恢复同一 sessionId

### Requirement: 自适应诊断上下文边界
adaptive 策略的上下文 provider SHALL 返回包含不透明 fingerprint 与可持久化字符串 attributes 的诊断上下文。系统 SHALL 在创建 automatic-managed 会话时采样上下文，并在 recording 状态的统一 dispatch 前重新采样；fingerprint 变化 SHALL 在事件元数据分配前触发 `contextChanged` rollover，相同 fingerprint MUST NOT 触发 rollover。fingerprint 仅用于进程内比较且 MUST NOT 自动持久化，attributes SHALL 写入对应新会话。provider 异常 MUST NOT 逃逸到宿主或中断事件采集。

#### Scenario: 上下文保持不变
- **WHEN** provider 连续返回相同 fingerprint
- **THEN** 系统保持当前 sessionId，不重置 sequence

#### Scenario: 用户或租户上下文变化
- **WHEN** provider 返回与当前 automatic-managed 会话不同的 fingerprint，随后有一条可接受事件进入 dispatch
- **THEN** 旧会话以 contextChanged 原因结束，新会话保存新上下文的 attributes，且该事件成为新会话的 sequence 1

#### Scenario: 路由变化不是上下文边界
- **WHEN** `currentRoute` 改变但上下文 fingerprint 不变
- **THEN** 系统不因路由变化创建新的 sessionId

#### Scenario: 上下文 provider 抛出异常
- **WHEN** provider 在会话创建或 dispatch 前抛出异常
- **THEN** 系统捕获并报告该异常，沿用最近一次有效上下文与当前 sessionId，并继续处理原事件

### Requirement: 自动 rollover 与事件存储顺序
automatic rollover SHALL 在运行时同步完成旧会话结束、新会话激活和 sequence 重置，并将旧会话 complete、新会话 begin 与触发事件 append 依次排入现有存储串行队列。任意并发 lifecycle、上下文检查和 dispatch MUST NOT 产生两个活动会话、把触发事件写入旧会话或使新会话 sequence 跳号。自动 rollover MUST NOT 执行逐事件强制 flush；既有后台与 crash flush 规则保持有效。

#### Scenario: rollover 触发事件的归属
- **WHEN** 一个事件同时发现 maxDuration 或 contextChanged 边界
- **THEN** complete(old)、begin(new)、append(event) 按顺序排队，listener metadata 与持久化 record 都指向新 sessionId 和 sequence 1

#### Scenario: 多个边界同时成立
- **WHEN** 同一次策略检查同时发现后台超时、最大时长或上下文变化中的多个条件
- **THEN** 系统只执行一次 rollover，并以确定性的优先级记录一个结束原因

#### Scenario: process 与 manual 不进入策略检查
- **WHEN** 当前会话使用 process 策略、manual 模式或由调用方显式创建
- **THEN** dispatch 沿用现有门控与 sequence 分配流程，不执行 automatic rollover

### Requirement: 会话生命周期控制
`ArgosManager` SHALL 提供开始、暂停、恢复和停止诊断会话的 API，并保证任意时刻最多存在一个未结束会话。开始操作在 recording 状态 SHALL 幂等返回当前会话，在 paused 状态 SHALL 恢复当前会话；停止操作 SHALL 写入 `endedAt` 与 `endReason == completed` 并清除活动会话。

#### Scenario: 从 idle 开始会话
- **WHEN** 系统处于 idle 且调用方开始会话
- **THEN** 系统创建并暴露新的 activeSession，状态切换为 recording

#### Scenario: 暂停与恢复同一会话
- **WHEN** recording 会话被暂停后再恢复
- **THEN** 暂停期间 activeSession.id 不变，恢复后仍使用同一会话且状态回到 recording

#### Scenario: recording 状态重复开始
- **WHEN** 已有 recording 会话时再次调用开始操作
- **THEN** 系统返回现有会话，不结束或替换它，也不重置 sequence

#### Scenario: 显式停止会话
- **WHEN** 调用方停止当前 recording 或 paused 会话
- **THEN** 会话写入结束时间和 completed 原因，系统状态变为 idle，后续事件不再关联该会话

#### Scenario: idle 状态停止
- **WHEN** 系统处于 idle 时调用停止操作
- **THEN** 操作安全返回无活动会话，不创建空会话且不抛异常

### Requirement: captureEnabled 兼容映射
`ArgosManager.captureEnabled` SHALL 保留为兼容属性并反映 `sessionState == recording`。将其设为 false SHALL 暂停当前 recording 会话；将其设为 true SHALL 恢复 paused 会话，或在 idle 时创建新会话。该属性 MUST NOT 再只控制 HTTP 事件。

#### Scenario: 兼容属性暂停会话
- **WHEN** activeSession 正在 recording 且调用方设置 `captureEnabled = false`
- **THEN** activeSession 保留、sessionState 变为 paused，之后所有已启用 capability 的新事件均不进入 listener 或存储

#### Scenario: 兼容属性恢复会话
- **WHEN** activeSession 处于 paused 且调用方设置 `captureEnabled = true`
- **THEN** 同一会话恢复为 recording，下一条事件继续使用该 sessionId 和后续 sequence

#### Scenario: idle 时开启兼容属性
- **WHEN** sessionState 为 idle 且调用方设置 `captureEnabled = true`
- **THEN** 系统创建一个新会话并开始 recording

### Requirement: 事件关联、唯一标识与稳定顺序
所有通过统一 dispatch 接受的事件 SHALL 绑定当前 activeSession.id，并获得会话内从 1 开始严格递增的 `sequence`；现有 `ArgosPacketRecord.id` SHALL 作为事件 ID，并为所有新事件生成跨会话不重复的值。`ArgosPacketRecord` SHALL 以可空 `sessionId` 和默认值为 0 的 `sequence` 兼容旧构造和旧 JSON；listener 收到的 `ArgosBaseModel` SHALL 暴露与对应持久化记录一致的不可变事件元数据。时间戳负责展示，sequence 负责会话内稳定排序。

#### Scenario: 不同类型事件共享会话
- **WHEN** 同一 recording 会话依次产生网络、资源、卡顿和 crash 事件
- **THEN** 四条记录及其 listener 模型具有相同的非空 sessionId，并按接收顺序获得连续递增的 sequence 与各自唯一 id

#### Scenario: 同毫秒事件仍稳定排序
- **WHEN** 同一会话中的两条事件拥有相同 startTimestamp
- **THEN** 两条记录的 id 不同，并可通过 sequence 确定稳定先后顺序

#### Scenario: 旧记录缺少关联字段
- **WHEN** 反序列化不含 sessionId 和 sequence 的既有记录
- **THEN** sessionId 降级为 null、sequence 降级为 0、既有 id 原样保留，记录仍可读取和展示且不被自动伪装为某个新会话的事件

#### Scenario: 非 recording 状态拒绝事件
- **WHEN** 系统处于 idle 或 paused 且任一 monitor 尝试 dispatch 事件
- **THEN** 事件不进入 listener、不写入存储，也不消耗任何会话 sequence

### Requirement: 异常中断恢复
存储初始化 SHALL 检测先前持久化但没有 `endedAt` 的会话，并在创建本次自动会话之前将其结束原因为 `interrupted`；恢复后的 endedAt SHALL 使用 lastEventAt，若不存在则使用 startedAt。恢复 MUST NOT 将旧会话继续作为当前进程的 activeSession。

#### Scenario: App 被杀后恢复未结束会话
- **WHEN** 持久化数据中存在 endedAt 为空且带有事件的旧会话，随后新进程初始化存储
- **THEN** 旧会话被标记为 interrupted、endedAt 等于 lastEventAt，并与新进程的自动会话保持不同 id

#### Scenario: 空会话被中断
- **WHEN** 持久化数据中存在 endedAt 和 lastEventAt 都为空的旧会话
- **THEN** 旧会话被标记为 interrupted，endedAt 使用 startedAt，恢复流程不抛异常

### Requirement: 会话查询
系统 SHALL 提供读取全部会话、读取指定会话事件和读取 activeSession 的接口。持久化会话 SHALL 按 startedAt 倒序返回；指定会话事件 SHALL 按 sequence 升序返回，sequence 为 0 的兼容记录再按 startTimestamp 与 id 稳定排序。

#### Scenario: 查询会话列表
- **WHEN** 存储中存在多个已结束和活动会话并调用会话列表接口
- **THEN** 返回结果按 startedAt 从新到旧排列，并包含每个会话的 truncated 与结束状态

#### Scenario: 查询单个会话时间顺序
- **WHEN** 调用方按 sessionId 查询某个会话的事件
- **THEN** 只返回该 sessionId 的记录，并按 sequence 从小到大排列

#### Scenario: 查询不存在的会话
- **WHEN** 使用不存在的 sessionId 查询事件
- **THEN** 返回空列表且不抛异常

### Requirement: App 生命周期不隐式结束会话
进入单个 paused、inactive、detached 或 resumed 生命周期状态 MUST NOT 立即结束当前诊断会话；后台或 detached 时系统 SHALL 刷新待落盘数据。manual 会话、显式创建会话和 process 策略会话 SHALL 在进程存活时始终保留原 sessionId。adaptive 策略 SHALL 记录可靠的后台起点，并仅在 recording 的 automatic-managed 会话恢复前台且实际后台时长达到 `backgroundTimeout` 时执行一次 `backgroundTimeout` rollover；短暂后台、inactive 抖动和显式 paused 会话 MUST NOT rollover。实现 MUST NOT 依赖 App 在后台期间执行定时器。

#### Scenario: process 策略退到后台后继续同一会话
- **WHEN** process 策略的 recording 会话进入后台并随后恢复到前台且进程未终止
- **THEN** 系统先 flush 存储但保留相同 activeSession.id，恢复后继续在同一会话中记录

#### Scenario: adaptive 策略短暂后台
- **WHEN** adaptive 策略的 recording 会话进入后台并在 backgroundTimeout 之前恢复
- **THEN** 系统保留相同 activeSession.id 和下一 sequence

#### Scenario: adaptive 策略后台超时
- **WHEN** adaptive 策略的 recording 会话进入后台并在达到 backgroundTimeout 后恢复
- **THEN** 系统以 backgroundTimeout 原因结束旧会话并立即创建不同 sessionId 的 automatic-managed 会话，且新会话 sequence 从 1 开始

#### Scenario: 后台截止时间与事件时间一致
- **WHEN** 旧会话在后台截止时间之后仍存在已接受事件
- **THEN** 旧会话 endedAt 不早于 lastEventAt，否则 endedAt 使用后台起点加 backgroundTimeout，且新会话 startedAt 使用实际恢复时间

#### Scenario: 显式暂停优先于自适应后台边界
- **WHEN** adaptive 策略会话在进入后台前已由调用方显式 pause，并在超时后恢复 App
- **THEN** 系统保留 paused 状态与原 sessionId，直到调用方显式 resume
