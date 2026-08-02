## ADDED Requirements

### Requirement: 版本化诊断存储信封与旧格式迁移
系统 SHALL 在新的 `argos_diagnostic_store_v1` 逻辑存储键下通过 `ArgosStorageAdapter` 持久化带 `schemaVersion`、`sessions` 与 `records` 的 JSON 对象。新 key 不存在时 SHALL 回退读取既有 `argos_packet_records` 顶层 JSON List，将其中元素作为 sessionId 为空的历史 records 加载，并在下一次成功落盘时写入新 key；迁移 MUST NOT 丢弃可解析的旧记录，也 MUST NOT 在迁移时删除或覆盖 legacy key。

#### Scenario: 读取新版信封
- **WHEN** adapter 返回包含受支持 schemaVersion、sessions 和 records 的 JSON 对象
- **THEN** 系统恢复会话与记录缓存，并执行未结束会话的 interrupted 恢复

#### Scenario: 读取旧版记录列表
- **WHEN** 新 key 不存在且 legacy key 返回既有顶层 JSON List
- **THEN** 每条可解析记录均被加载为 sessionId 为空、sequence 为 0 的历史记录，sessions 初始为空且读取不抛异常

#### Scenario: 旧格式在下一次落盘升级
- **WHEN** 已加载旧版 List 后发生任一会改变会话或记录的操作并成功 flush
- **THEN** adapter 的新 key 包含新版版本化信封和原有可解析记录，legacy key 保持不变以支持安全回滚

### Requirement: 会话操作共享串行队列
开始、暂停、恢复、结束、恢复中断会话、追加事件、查询、清空与 flush SHALL 进入同一个串行操作队列，保证会话元数据和记录之间的全序。开始会话操作 MUST 排在该会话第一条事件之前，结束操作 MUST 排在此前已发起的全部事件写入之后。

#### Scenario: 会话创建后立即发生事件
- **WHEN** 开始会话后不等待落盘就立即 dispatch 一条事件
- **THEN** 串行缓存中先存在该会话元数据，再存在引用其 id 的事件，不产生 orphan record

#### Scenario: 结束与在途事件有序
- **WHEN** 一条事件写入已发起但尚未落盘时调用 stopSession
- **THEN** 事件先归入该会话，随后会话写入 endedAt，结束操作不会漏掉此前已接收的事件


## MODIFIED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 Argos 事件记录与诊断会话元数据序列化为版本化 JSON 信封，并通过配置的 `ArgosStorageAdapter` 持久化到本地；未配置 adapter 时持久化操作 SHALL 为 no-op，但内存中的活动会话和 listener 数据流仍可工作。

#### Scenario: 事件完成后自动写入所属会话
- **WHEN** 一条事件通过统一 dispatch 被接受、存在 activeSession 且 `ArgosConfig.enableStorage` 为 true
- **THEN** 系统把带 sessionId、sequence 和唯一 id 的记录追加到信封 records，并更新对应会话的 lastEventAt

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 enableStorage 或将其设为 false
- **THEN** 系统不向 adapter 写入诊断信封，已有持久化数据不受影响

#### Scenario: 未配置 adapter
- **WHEN** enableStorage 为 true 但 storageAdapter 为空
- **THEN** listener 仍可收到 recording 会话中的事件，持久化读写安全返回且不抛异常

### Requirement: 最大记录条数限制
系统 SHALL 按会话执行保留：`ArgosConfig.maxSessions`（默认 5）限制持久化会话总数，超限时整体删除 startedAt 最早的已结束会话及其全部 records，MUST NOT 淘汰当前 activeSession。每个会话内部仍按 `ArgosPacketRecord.kind` 分区限制记录数：resource 使用 `resourceMaxRecords`，其余类型使用 `maxPacketRecords`；活动会话发生任一记录淘汰时 SHALL 设置 `truncated == true`。sessionId 为空的旧记录作为单独历史桶按原有每类型配额处理，但不计入 maxSessions。

#### Scenario: 会话数量超限时整体淘汰
- **WHEN** 新会话写入后持久化会话数超过 maxSessions，且存在多个已结束会话
- **THEN** 系统删除最旧已结束会话及其所有 records，保留其他会话内部完整的关联关系

#### Scenario: 活动会话不被整体淘汰
- **WHEN** 达到 maxSessions 且最早的会话仍是当前 activeSession
- **THEN** 系统选择最旧的其他已结束会话淘汰；若不存在可淘汰的已结束会话，则暂时允许超限而不删除 activeSession

#### Scenario: 活动会话类型超限
- **WHEN** activeSession 中某一类型的新记录使该类型超过对应配额
- **THEN** 系统只删除该会话内该类型最早的记录，并将该会话标记为 truncated，其他类型和其他会话不受影响

#### Scenario: 资源记录不挤掉 crash
- **WHEN** 同一会话持续写入资源采样直至超过 resourceMaxRecords
- **THEN** 只淘汰该会话最旧的资源记录，network、jank 和 crash 记录仍然保留

#### Scenario: 自定义资源配额
- **WHEN** 用户在 ArgosConfig 中设置 resourceMaxRecords 为自定义值
- **THEN** 系统以该值作为每个会话内部 resource 记录的保留上限

#### Scenario: 自定义非资源配额
- **WHEN** 用户在 ArgosConfig 中设置 maxPacketRecords 为自定义值
- **THEN** 系统以该值作为每个会话内部每种非资源类型的独立保留上限

#### Scenario: 向后兼容默认值
- **WHEN** 用户未设置 resourceMaxRecords、maxPacketRecords 或 maxSessions
- **THEN** 每个会话的 resource 类型使用上限 50、每种非资源类型使用上限 200，持久化会话总数使用上限 5

#### Scenario: 旧记录兼容配额
- **WHEN** 从旧格式加载 sessionId 为空的记录并继续写入未归属兼容记录
- **THEN** 这些记录按 kind 使用全局兼容桶配额，不创建伪造会话

### Requirement: 读取所有抓包记录
系统 SHALL 提供接口读取所有已存储的事件记录，返回按 startTimestamp 倒序排列的兼容全局列表；同时 SHALL 允许会话查询接口从同一内存信封读取数据。所有读取 SHALL 经统一操作队列执行，并反映此前已发起的会话与事件变更。

#### Scenario: 有记录时返回兼容列表
- **WHEN** 调用 `ArgosPacketStorage.getAllAsync()`
- **THEN** 返回所有会话记录与未归属历史记录的合并列表，按 startTimestamp 倒序排列

#### Scenario: 无记录时返回空列表
- **WHEN** 信封中没有任何 records 时调用 getAllAsync
- **THEN** 返回空列表，不抛出异常

#### Scenario: 读取反映此前写入
- **WHEN** 发起会话创建和若干事件写入后紧接着调用读取
- **THEN** 返回结果包含此前已发起的全部有效写入，不会读到队列中间态

### Requirement: 清空所有抓包记录
系统 SHALL 提供接口一次性清空所有诊断会话、会话 records 与未归属历史记录。清空 SHALL 经统一操作队列执行并清除新版与 legacy 两个逻辑存储 key；若当前仍处于 recording，运行时 activeSession SHALL 同时结束并回到 idle，避免后续事件引用已被删除的会话。

#### Scenario: 清空全部诊断数据
- **WHEN** 调用 `ArgosPacketStorage.clear()`
- **THEN** sessions 与 records 均为空，随后所有会话和记录查询返回空结果

#### Scenario: recording 期间清空
- **WHEN** activeSession 正在 recording 时调用 clear
- **THEN** 当前会话和事件被删除，ArgosManager 回到 idle 且 captureEnabled 为 false，下一次开启录制会创建新 sessionId

#### Scenario: 清空与写入有序
- **WHEN** 在存在在途事件写入时调用 clear
- **THEN** 清空与此前写入按发起顺序执行，已清空数据不会被在途写入复活

### Requirement: 错误请求也持久化存储
系统 SHALL 在 HTTP 请求失败时（`ArgosHttpInfo.error != null`）将错误快照通过统一 dispatch 持久化到所属诊断会话，与正常网络记录共享同一 session 内 network 配额。错误记录属于 network 类型，并通过配置的 `ArgosStorageAdapter` 写入版本化诊断信封。

#### Scenario: 错误记录写入诊断存储
- **WHEN** recording 会话中一次 HTTP 请求因网络异常失败，enableStorage 为 true，且该请求满足既有 host 规则
- **THEN** 所属会话增加一条 network 记录，其中 responseCode 为 0、responseBody 为空、error 包含错误描述，并携带 sessionId 与 sequence

#### Scenario: 错误记录参与 session 内 network 配额淘汰
- **WHEN** 错误记录写入后，该会话的 network 记录数超过 maxPacketRecords
- **THEN** 系统淘汰该会话 network 类型中 sequence 最早的记录，并标记 session truncated；其他会话和其他类型不受影响

### Requirement: ArgosPacketRecord 包含路由名称字段
`ArgosPacketRecord` SHALL 包含 `routeName` 字段（String，默认空字符串），记录事件完成时宿主 App 当前页面路由名称，并与 sessionId、sequence 一起通过诊断信封持久化。

#### Scenario: routeName 随会话记录持久化
- **WHEN** 一条事件记录通过统一 dispatch 写入所属会话
- **THEN** 该记录 JSON 包含 routeName 键，其值为 dispatch 时 `ArgosManager.instance.currentRoute` 的快照

#### Scenario: 反序列化旧记录时 routeName 降级为空字符串
- **WHEN** 从 legacy key 读取一条不含 routeName 的旧格式记录
- **THEN** `ArgosPacketRecord.routeName` 为空字符串，不抛出异常且不影响 session 迁移
