## MODIFIED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应，含路由名称）序列化为 JSON 并通过可插拔的存储后端持久化到本地。存储 key 为 `argos_packet_records`；当宿主选择 MMKV 适配器时，使用独立 mmapID `"argos"`。

#### Scenario: 请求完成后自动写入（含路由名称）
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `ArgosConfig.enableStorage` 为 `true`
- **THEN** 系统将该次请求的快照数据（含 `routeName` 字段）追加写入存储后端，写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向存储后端写入任何抓包数据，已有记录不受影响

### Requirement: 最大记录条数限制
系统 SHALL 限制存储后端中存储的抓包记录总数，超出上限时自动淘汰最旧记录。

#### Scenario: 超出最大条数时淘汰旧记录
- **WHEN** 新记录写入后存储总条数超过 `ArgosConfig.maxPacketRecords`（默认 200）
- **THEN** 系统删除时间最早的记录，直到总条数不超过上限

#### Scenario: 自定义最大条数
- **WHEN** 用户在 `ArgosConfig` 中设置 `maxPacketRecords` 为自定义值（如 50）
- **THEN** 系统使用该自定义值作为上限进行淘汰

### Requirement: 读取所有抓包记录
系统 SHALL 提供接口从存储后端读取所有已存储的抓包记录，返回按时间倒序排列的列表。

#### Scenario: 有记录时返回列表
- **WHEN** 调用 `ArgosPacketStorage.getAll()`
- **THEN** 返回当前存储后端中所有记录的列表，按 `startTimestamp` 倒序排列

#### Scenario: 无记录时返回空列表
- **WHEN** 存储后端中没有任何抓包记录时调用 `ArgosPacketStorage.getAll()`
- **THEN** 返回空列表，不抛出异常

### Requirement: 清空所有抓包记录
系统 SHALL 提供接口一次性清空存储后端中存储的所有抓包记录。

#### Scenario: 清空操作
- **WHEN** 调用 `ArgosPacketStorage.clear()`
- **THEN** 存储后端中的所有抓包记录被删除，随后调用 `getAll()` 返回空列表

### Requirement: 错误请求也持久化存储
系统 SHALL 在 HTTP 请求失败时（`ArgosHttpInfo.error != null`）将错误快照持久化到存储后端，与正常请求记录共享同一存储和上限机制。

#### Scenario: 错误记录写入存储后端
- **WHEN** 一次 HTTP 请求因网络异常失败，且 `enableStorage` 为 `true`，且 host 在白名单中
- **THEN** 存储后端中增加一条记录，其中 `responseCode = 0`，`responseBody = ''`，`error` 字段包含错误描述

#### Scenario: 错误记录参与最大条数淘汰
- **WHEN** 错误记录写入后总条数超过 `maxPacketRecords`
- **THEN** 最旧的记录（无论是正常还是错误）被淘汰，直到总条数不超过上限

### Requirement: ArgosPacketRecord 包含路由名称字段
`ArgosPacketRecord` SHALL 包含 `routeName` 字段（`String`，默认空字符串），记录请求响应完成时宿主 App 当前所在的页面路由名称。

#### Scenario: routeName 随记录持久化
- **WHEN** 一条抓包记录被写入存储后端
- **THEN** 该记录的 JSON 中包含 `routeName` 键，值为写入时 `ArgosManager.instance.currentRoute` 的快照

#### Scenario: 反序列化旧记录时 routeName 降级为空字符串
- **WHEN** 从存储后端读取一条不含 `routeName` 键的旧格式记录
- **THEN** `ArgosPacketRecord.routeName` 为空字符串，不抛出异常

### Requirement: currentRoute 运行时可更新
`ArgosManager` SHALL 提供可写属性 `currentRoute`（`String`），宿主 App 在路由变更时主动赋值，`_dispatchHttpInfo` 写入快照时读取该值注入 `routeName`。

#### Scenario: 宿主更新 currentRoute 后的请求携带新路由
- **WHEN** 宿主将 `ArgosManager.instance.currentRoute` 设为 `"/detail"` 后发起一次 HTTP 请求
- **THEN** 该请求完成后存储的记录 `routeName` 为 `"/detail"`

#### Scenario: currentRoute 初始值为空字符串
- **WHEN** 宿主未设置 `currentRoute` 就有请求完成
- **THEN** 该记录的 `routeName` 为空字符串
