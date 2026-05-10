## MODIFIED Requirements

### Requirement: 通过 ArgosConfig 初始化时注入 proxyProvider
`ArgosConfig` SHALL 新增可选字段 `proxyProvider: String? Function()?`，允许在初始化阶段声明动态代理 provider。

#### Scenario: 初始化时配置 proxyProvider
- **WHEN** 调用 `ArgosManager.instance.init(config: ArgosConfig(proxyProvider: () => getProxy()))` 时
- **THEN** `ArgosHttpMonitor` 的 `proxyProvider` 被设置为该回调，后续所有请求使用该 provider

### Requirement: 运行时替换 proxyProvider
`ArgosManager` SHALL 提供 `updateProxyProvider(String? Function() provider)` 方法，允许在初始化后动态替换 provider。

#### Scenario: 运行时更新 provider
- **WHEN** 调用 `ArgosManager.instance.updateProxyProvider(() => newProxy)`
- **THEN** `ArgosHttpMonitor.proxyProvider` 被替换为新回调，此后的请求使用新 provider

### Requirement: 移除静态 updateProxy 方法
系统 SHALL 移除 `ArgosManager.updateProxy(String proxy)` 方法。

#### Scenario: 调用方迁移到 updateProxyProvider
- **WHEN** 调用方原来使用 `updateProxy("http://host:port")`
- **THEN** 应迁移为 `updateProxyProvider(() => "http://host:port")`，行为等价
