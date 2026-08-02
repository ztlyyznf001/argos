## ADDED Requirements

### Requirement: 诊断会话数据模型
系统 SHALL 提供可序列化的 `ArgosDiagnosticSession`，至少包含不透明唯一 `id`、`startedAt`、可空 `endedAt`、可空 `lastEventAt`、可空 `label`、可空 `note`、字符串键值 `attributes`、可空 `endReason` 与 `truncated` 标记。时间字段 SHALL 使用 Unix 毫秒时间戳；运行时状态 SHALL 区分 `idle`、`recording` 与 `paused`，持久化后的结束原因 SHALL 至少区分 `completed` 与 `interrupted`。

#### Scenario: 创建新会话
- **WHEN** 系统开始一次新的诊断会话
- **THEN** 会话获得非空且不与已有会话重复的 `id`、当前 `startedAt`、空 `endedAt`、`truncated == false`，并保留调用方提供的 label 与 attributes

#### Scenario: 会话序列化往返
- **WHEN** 一个包含 label、note、attributes、结束时间和结束原因的会话经过 JSON 序列化后再反序列化
- **THEN** 所有字段保持一致，未知附加字段不会导致反序列化失败

### Requirement: 自动与手动会话模式
`ArgosConfig` SHALL 提供 `sessionMode`，支持 `automatic` 与 `manual`，默认值为 `automatic`。为保持既有初始化行为，automatic 模式 SHALL 在 `enableStorage == true` 时于首次 `ArgosManager.init()` 自动开始录制会话；manual 模式 SHALL 等待显式开始。重复调用 `init()` MUST NOT 创建重复活动会话。

#### Scenario: 自动模式初始化
- **WHEN** 使用默认 sessionMode 和 `enableStorage == true` 首次初始化 ArgosManager
- **THEN** 系统创建一个活动会话，运行时状态为 `recording`，`captureEnabled == true`

#### Scenario: 手动模式初始化
- **WHEN** 使用 `sessionMode == manual` 初始化 ArgosManager
- **THEN** 系统不创建活动会话，运行时状态为 `idle`，直到调用方显式开始会话

#### Scenario: 自动模式保持存储关闭兼容行为
- **WHEN** 使用默认 sessionMode 和 `enableStorage == false` 初始化 ArgosManager
- **THEN** 系统不自动开始会话且 `captureEnabled == false`；调用方仍可显式开始仅存在于内存和 listener 数据流中的会话

#### Scenario: 重复初始化不重复建会话
- **WHEN** ArgosManager 已有 recording 或 paused 会话时再次调用 `init()`
- **THEN** 系统保留原活动会话，不创建第二个活动会话

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
App 进入 paused、inactive、detached 或再次 resumed SHALL NOT 单独结束当前诊断会话；后台或 detached 时系统 SHALL 刷新待落盘数据。只有显式停止或下次启动时的中断恢复会结束会话。

#### Scenario: 退到后台后继续同一会话
- **WHEN** recording 会话期间 App 进入后台并随后恢复到前台且进程未终止
- **THEN** 系统先 flush 存储但保留相同 activeSession.id，恢复后继续在同一会话中记录
