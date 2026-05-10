## Context

`KurilHttpOverrides._findProxy` 是 Dart `HttpOverrides` 机制在每次建立 TCP 连接前调用的钩子，用于决定是否通过代理。当前实现通过 `KurilHttpMonitor.customProxy: String?` 存储一个静态代理字符串，调用方通过 `KurilApmManager.updateProxy(String)` 手动刷新。

这种模式要求调用方感知代理变化并主动推送，不适合代理地址由外部系统（如运行时配置中心、VPN 状态检测）动态决定的场景。

## Goals / Non-Goals

**Goals:**
- 支持调用方通过 `String? Function()?` 回调动态提供代理地址
- 每次 `_findProxy` 调用时实时执行回调，不缓存结果
- 保持 `KurilApmConfig` 的初始化路径一致（在 `init` 时注入 provider）
- 运行时可通过 `KurilApmManager.updateProxyProvider` 替换 provider

**Non-Goals:**
- 不支持异步 provider（`_findProxy` 是同步接口，Dart `HttpClient` 不支持异步代理解析）
- 不提供代理认证的动态化（`authenticateProxy` 不在本次范围内）
- 不向后兼容旧的 `updateProxy(String)` 方法

## Decisions

### 用 `String? Function()?` 替代 `String? customProxy`

`_findProxy` 每次请求触发，直接调用 provider 即可实现"实时取值"语义，无需额外同步机制。如果保留 `customProxy` 字段再加一个 provider 字段会造成歧义（两者都存在时谁优先？）。因此直接替换，语义更清晰。

**替代方案**: 保留 `customProxy`，仅新增 `proxyProvider`，provider 优先。
**否决理由**: 双字段增加维护成本，且 `updateProxy` 的调用方本来就很少，Breaking change 可接受。

### Provider 在 `KurilApmConfig` 中声明，也可通过 manager 运行时替换

`KurilApmConfig` 是初始化入口，provider 作为配置字段语义自然。`KurilApmManager.updateProxyProvider` 允许在已初始化后动态切换，满足 provider 本身依赖运行时状态的场景。

### `_findProxy` 同步调用 provider，不做缓存

`_findProxy` 由 Dart IO 层同步调用，不能返回 Future。provider 回调必须同步，由调用方保证线程安全（通常代理地址读取是内存操作，无阻塞风险）。

## Risks / Trade-offs

- **Breaking change**: 移除 `updateProxy(String)` → 调用方必须迁移，需在 CHANGELOG 和 README 中标注
- **Provider 抛异常**: 若 provider 回调抛出未捕获异常，`_findProxy` 会传播异常导致请求失败 → Mitigation: `_findProxy` 内 try-catch，异常时降级为 `DIRECT`
- **provider 为 null**: 无 provider 时行为与现有"无代理"一致，直接走 `HttpClient.findProxyFromEnvironment` 无额外环境变量

## Migration Plan

1. 修改 `KurilHttpMonitor`、`KurilApmConfig`、`KurilApmManager`
2. 调用 `updateProxy(proxy)` 的地方改为 `updateProxyProvider(() => proxy)`
3. 通过 `KurilApmConfig(proxyProvider: () => currentProxy)` 初始化的场景直接使用新字段
