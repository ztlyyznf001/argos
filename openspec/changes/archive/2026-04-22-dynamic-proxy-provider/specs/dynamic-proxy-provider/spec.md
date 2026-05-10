## ADDED Requirements

### Requirement: 通过回调动态提供代理地址
系统 SHALL 支持调用方通过 `String? Function()?` 类型的 `proxyProvider` 回调来动态提供代理地址。每次 HTTP 请求建立连接前，系统 MUST 调用该回调以获取当前代理地址，而非使用缓存值。

#### Scenario: 每次请求实时调用 provider
- **WHEN** `proxyProvider` 已设置，且发起 HTTP 请求
- **THEN** 系统在 `_findProxy` 中调用 `proxyProvider()` 获取代理地址，并将其用于本次请求的代理解析

#### Scenario: provider 返回 null 时不使用代理
- **WHEN** `proxyProvider` 返回 `null` 或空字符串
- **THEN** 系统回退到 `HttpClient.findProxyFromEnvironment` 的默认行为（不注入额外环境变量），等同于直连

#### Scenario: provider 未设置时行为不变
- **WHEN** `proxyProvider` 为 `null`（未配置）
- **THEN** 系统使用 `HttpClient.findProxyFromEnvironment` 默认行为，与无代理配置时一致

#### Scenario: provider 抛出异常时请求不崩溃
- **WHEN** `proxyProvider` 调用抛出异常
- **THEN** 系统捕获异常，降级为直连（`DIRECT`），HTTP 请求正常继续

### Requirement: 通过 KurilApmConfig 初始化时注入 proxyProvider
`KurilApmConfig` SHALL 新增可选字段 `proxyProvider: String? Function()?`，允许在初始化阶段声明动态代理 provider。

#### Scenario: 初始化时配置 proxyProvider
- **WHEN** 调用 `KurilApmManager.instance.init(config: KurilApmConfig(proxyProvider: () => getProxy()))` 时
- **THEN** `KurilHttpMonitor` 的 `proxyProvider` 被设置为该回调，后续所有请求使用该 provider

### Requirement: 运行时替换 proxyProvider
`KurilApmManager` SHALL 提供 `updateProxyProvider(String? Function() provider)` 方法，允许在初始化后动态替换 provider。

#### Scenario: 运行时更新 provider
- **WHEN** 调用 `KurilApmManager.instance.updateProxyProvider(() => newProxy)`
- **THEN** `KurilHttpMonitor.proxyProvider` 被替换为新回调，此后的请求使用新 provider

### Requirement: 移除静态 updateProxy 方法
系统 SHALL 移除 `KurilApmManager.updateProxy(String proxy)` 方法。

#### Scenario: 调用方迁移到 updateProxyProvider
- **WHEN** 调用方原来使用 `updateProxy("http://host:port")`
- **THEN** 应迁移为 `updateProxyProvider(() => "http://host:port")`，行为等价
