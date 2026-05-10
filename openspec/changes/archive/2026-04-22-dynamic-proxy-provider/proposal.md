## Why

当前的代理地址通过 `KurilApmManager.updateProxy(String proxy)` 静态设置，调用方必须在代理地址变化时主动调用该方法更新。这无法满足代理地址需要在每次请求时动态获取的场景（例如代理地址由外部运行时决定，或随时间变化）。

## What Changes

- 在 `KurilApmConfig` 中新增 `proxyProvider` 字段（类型 `String? Function()?`），替代静态代理字符串配置
- `KurilHttpMonitor` 以 `proxyProvider` 回调替代 `customProxy` 字段；每次 `_findProxy` 调用时实时调用回调获取最新代理地址
- `KurilApmManager` 新增 `updateProxyProvider(String? Function() provider)` 方法，允许运行时动态替换 provider
- **BREAKING**: 移除 `KurilApmManager.updateProxy(String proxy)` 方法，改用 `updateProxyProvider`
- `KurilApmManager.init` 将 config 中的 `proxyProvider` 传递给 `KurilHttpMonitor`

## Capabilities

### New Capabilities

- `dynamic-proxy-provider`: 支持通过回调函数动态提供代理地址，每次 HTTP 请求时实时调用回调获取当前代理

### Modified Capabilities

（无现有 spec 需变更）

## Impact

- **`lib/config/kuril_apm_config.dart`**: 新增 `proxyProvider` 字段
- **`lib/apm/kuril_http_monitor.dart`**: `customProxy: String?` 替换为 `proxyProvider: String? Function()?`，`_findProxy` 改为调用回调
- **`lib/kuril_apm_manager.dart`**: 移除 `updateProxy`，新增 `updateProxyProvider`；`init` 时将 config.proxyProvider 写入 monitor
- **Public API breaking change**: 使用 `updateProxy` 的调用方需迁移到 `updateProxyProvider`
