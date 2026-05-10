## MODIFIED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应，含路由名称）序列化为 JSON 并通过 MMKV 持久化到本地。

#### Scenario: 请求完成后自动写入（含路由名称）
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `KurilApmConfig.enableStorage` 为 `true`
- **THEN** 系统将该次请求的快照数据（含 `routeName` 字段）追加写入 MMKV，写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向 MMKV 写入任何抓包数据，已有记录不受影响

## ADDED Requirements

### Requirement: KurilPacketRecord 包含路由名称字段
`KurilPacketRecord` SHALL 包含 `routeName` 字段（`String`，默认空字符串），记录请求响应完成时宿主 App 当前所在的页面路由名称。

#### Scenario: routeName 随记录持久化
- **WHEN** 一条抓包记录被写入 MMKV
- **THEN** 该记录的 JSON 中包含 `routeName` 键，值为写入时 `KurilApmManager.instance.currentRoute` 的快照

#### Scenario: 反序列化旧记录时 routeName 降级为空字符串
- **WHEN** 从 MMKV 读取一条不含 `routeName` 键的旧格式记录
- **THEN** `KurilPacketRecord.routeName` 为空字符串，不抛出异常

### Requirement: currentRoute 运行时可更新
`KurilApmManager` SHALL 提供可写属性 `currentRoute`（`String`），宿主 App 在路由变更时主动赋值，`_dispatchHttpInfo` 写入快照时读取该值注入 `routeName`。

#### Scenario: 宿主更新 currentRoute 后的请求携带新路由
- **WHEN** 宿主将 `KurilApmManager.instance.currentRoute` 设为 `"/detail"` 后发起一次 HTTP 请求
- **THEN** 该请求完成后存储的记录 `routeName` 为 `"/detail"`

#### Scenario: currentRoute 初始值为空字符串
- **WHEN** 宿主未设置 `currentRoute` 就有请求完成
- **THEN** 该记录的 `routeName` 为空字符串
