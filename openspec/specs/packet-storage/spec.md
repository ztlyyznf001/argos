## ADDED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应，含路由名称）序列化为 JSON 并通过 MMKV 持久化到本地。

#### Scenario: 请求完成后自动写入（含路由名称）
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `ArgosConfig.enableStorage` 为 `true`
- **THEN** 系统将该次请求的快照数据（含 `routeName` 字段）追加写入 MMKV，写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向 MMKV 写入任何抓包数据，已有记录不受影响

### Requirement: 最大记录条数限制
系统 SHALL 限制 MMKV 中存储的抓包记录总数，超出上限时自动淘汰最旧记录。

#### Scenario: 超出最大条数时淘汰旧记录
- **WHEN** 新记录写入后存储总条数超过 `ArgosConfig.maxPacketRecords`（默认 200）
- **THEN** 系统删除时间最早的记录，直到总条数不超过上限

#### Scenario: 自定义最大条数
- **WHEN** 用户在 `ArgosConfig` 中设置 `maxPacketRecords` 为自定义值（如 50）
- **THEN** 系统使用该自定义值作为上限进行淘汰

### Requirement: 读取所有抓包记录
系统 SHALL 提供接口从 MMKV 读取所有已存储的抓包记录，返回按时间倒序排列的列表。

#### Scenario: 有记录时返回列表
- **WHEN** 调用 `ArgosPacketStorage.getAll()`
- **THEN** 返回当前 MMKV 中所有记录的列表，按 `startTimestamp` 倒序排列

#### Scenario: 无记录时返回空列表
- **WHEN** MMKV 中没有任何抓包记录时调用 `ArgosPacketStorage.getAll()`
- **THEN** 返回空列表，不抛出异常

### Requirement: 清空所有抓包记录
系统 SHALL 提供接口一次性清空 MMKV 中存储的所有抓包记录。

#### Scenario: 清空操作
- **WHEN** 调用 `ArgosPacketStorage.clear()`
- **THEN** MMKV 中的所有抓包记录被删除，随后调用 `getAll()` 返回空列表

### Requirement: 大 Body 截断
系统 SHALL 对超过 100KB 的请求体进行截断，只存储前 100KB 并在截断处附加截断标注；对于文本响应体，系统 SHALL 完整存储捕获到的响应内容，不因 100KB 阈值截断；对于非文本响应体，系统 SHALL 不存储 body 内容，仅保留元数据。

#### Scenario: 请求体超过 100KB
- **WHEN** 请求体字节数超过 100 * 1024 字节
- **THEN** 系统只存储前 100KB 内容，并在末尾追加字符串 `"[TRUNCATED]"`

#### Scenario: 文本响应体超过 100KB
- **WHEN** 响应 Content-Type 为文本类型，且响应体字节数超过 100 * 1024 字节
- **THEN** 系统完整存储响应体内容，不附加 `"[TRUNCATED]"`

#### Scenario: 非文本响应体
- **WHEN** 响应 Content-Type 为 `image/*`、`application/octet-stream` 或其他非文本类型
- **THEN** 系统不存储响应体文本内容，`responseBody` 为空字符串，`responseCode`、`responseHeaders` 和 `responseSize` 正常记录

### Requirement: 错误请求也持久化存储
系统 SHALL 在 HTTP 请求失败时（`ArgosHttpInfo.error != null`）将错误快照持久化到 MMKV，与正常请求记录共享同一存储和上限机制。

#### Scenario: 错误记录写入 MMKV
- **WHEN** 一次 HTTP 请求因网络异常失败，且 `enableStorage` 为 `true`，且 host 在白名单中
- **THEN** MMKV 中增加一条记录，其中 `responseCode = 0`，`responseBody = ''`，`error` 字段包含错误描述

#### Scenario: 错误记录参与最大条数淘汰
- **WHEN** 错误记录写入后总条数超过 `maxPacketRecords`
- **THEN** 最旧的记录（无论是正常还是错误）被淘汰，直到总条数不超过上限

### Requirement: ArgosPacketRecord 包含路由名称字段
`ArgosPacketRecord` SHALL 包含 `routeName` 字段（`String`，默认空字符串），记录请求响应完成时宿主 App 当前所在的页面路由名称。

#### Scenario: routeName 随记录持久化
- **WHEN** 一条抓包记录被写入 MMKV
- **THEN** 该记录的 JSON 中包含 `routeName` 键，值为写入时 `ArgosManager.instance.currentRoute` 的快照

#### Scenario: 反序列化旧记录时 routeName 降级为空字符串
- **WHEN** 从 MMKV 读取一条不含 `routeName` 键的旧格式记录
- **THEN** `ArgosPacketRecord.routeName` 为空字符串，不抛出异常

### Requirement: currentRoute 运行时可更新
`ArgosManager` SHALL 提供可写属性 `currentRoute`（`String`），宿主 App 在路由变更时主动赋值，`_dispatchHttpInfo` 写入快照时读取该值注入 `routeName`。

#### Scenario: 宿主更新 currentRoute 后的请求携带新路由
- **WHEN** 宿主将 `ArgosManager.instance.currentRoute` 设为 `"/detail"` 后发起一次 HTTP 请求
- **THEN** 该请求完成后存储的记录 `routeName` 为 `"/detail"`

#### Scenario: currentRoute 初始值为空字符串
- **WHEN** 宿主未设置 `currentRoute` 就有请求完成
- **THEN** 该记录的 `routeName` 为空字符串
