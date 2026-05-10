## 1. KurilApmConfig

- [x] 1.1 在 `lib/config/kuril_apm_config.dart` 的 `KurilApmConfig` 类中新增字段 `final String? Function()? proxyProvider`
- [x] 1.2 更新 `KurilApmConfig` 构造函数，添加可选参数 `this.proxyProvider`

## 2. KurilHttpMonitor

- [x] 2.1 将 `lib/apm/kuril_http_monitor.dart` 中 `KurilHttpMonitor` 的 `String? customProxy` 字段替换为 `String? Function()? proxyProvider`
- [x] 2.2 更新 `KurilHttpOverrides._findProxy`：将 `KurilHttpMonitor.instance.customProxy` 读取改为调用 `KurilHttpMonitor.instance.proxyProvider?.call()`，并用 try-catch 包裹，异常时返回 `'DIRECT'`

## 3. KurilApmManager

- [x] 3.1 在 `lib/kuril_apm_manager.dart` 的 `KurilApmManager.init` 中，将 `config?.proxyProvider` 赋值给 `KurilHttpMonitor.instance.proxyProvider`
- [x] 3.2 移除 `KurilApmManager.updateProxy(String proxy)` 方法
- [x] 3.3 新增 `KurilApmManager.updateProxyProvider(String? Function() provider)` 方法，将 provider 写入 `KurilHttpMonitor.instance.proxyProvider`

## 4. 验证

- [x] 4.1 更新 `example/lib/main.dart` 中使用 `updateProxy` 的调用，改为 `updateProxyProvider`（如有）
- [x] 4.2 运行 `dart analyze` 确认无编译错误
