## ADDED Requirements

### Requirement: 运行时抓包开关
`KurilApmManager` SHALL 提供可写属性 `captureEnabled`（`bool`），初始值由 `KurilApmConfig.enableStorage` 决定。`_dispatchHttpInfo` SHALL 在 `captureEnabled` 为 `false` 时跳过存储写入和 listener 回调。

#### Scenario: 关闭开关后请求不被记录
- **WHEN** `KurilApmManager.instance.captureEnabled` 被设为 `false`，之后发生 HTTP 请求
- **THEN** 该请求不写入 MMKV，listener 不被回调

#### Scenario: 重新开启后请求恢复记录
- **WHEN** `KurilApmManager.instance.captureEnabled` 被设回 `true`，之后发生 HTTP 请求
- **THEN** 该请求正常写入 MMKV（如 enableStorage 为 true），listener 正常回调

#### Scenario: 初始值与 enableStorage 一致
- **WHEN** `KurilApmManager.instance.init(config: KurilApmConfig(enableStorage: true))` 被调用
- **THEN** `KurilApmManager.instance.captureEnabled` 初始值为 `true`

#### Scenario: enableStorage 为 false 时初始值也为 false
- **WHEN** `KurilApmManager.instance.init(config: KurilApmConfig(enableStorage: false))` 被调用
- **THEN** `KurilApmManager.instance.captureEnabled` 初始值为 `false`
