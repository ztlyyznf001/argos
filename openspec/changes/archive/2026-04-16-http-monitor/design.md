## Context

`kuril_monitor` 是一个 Flutter HTTP 监控插件，通过 `HttpOverrides` 拦截全局 `HttpClient` 创建，以无侵入的方式捕获请求/响应数据。

当前状态：`KurilHttpOverrides.createHttpClient()` 仅在原始 `HttpClient` 上设置了 `findProxy`，**从未将其包装成 `KurilHttpClient`**，导致监控类的所有拦截逻辑（`KurilHttpClientRequest`、`KurilHttpClientResponse`）完全失效。数据模型、存储层、UI 层已就绪，唯独 capture 链路断路。

## Goals / Non-Goals

**Goals:**
- 接通 `HttpOverrides → KurilHttpClient → KurilHttpClientRequest → KurilHttpClientResponse` 完整链路
- 保证 `findProxy`（代理功能）在包装后继续生效
- 错误（网络异常、超时）时也写入存储和 listener
- 非文本响应（图片/二进制）不写入乱码，只记录元数据

**Non-Goals:**
- 不支持 Dio / http package 等第三方客户端的拦截（仅 `dart:io` HttpClient）
- 不修改 UI 层或存储层的现有实现
- 不引入新的外部依赖

## Decisions

### 决策 1：`createHttpClient` 返回 `KurilHttpClient`

`createHttpClient` 修改为：
```dart
HttpClient createHttpClient(SecurityContext? context) {
  final HttpClient raw = super.createHttpClient(context); // 或 origin?.createHttpClient
  raw.findProxy = _findProxy;
  raw.badCertificateCallback = ...;
  return KurilHttpClient(raw);
}
```

**备选方案**：在 `open/openUrl` 等方法外层再套一层 HttpOverrides 子类拦截 → 过于复杂，且同样要维护 delegate 全量接口。

### 决策 2：错误通过 `catchError` 在 `KurilHttpClient.monitor()` 捕获

在 `monitor()` 的 `catchError` 中将 `httpInfo.error` 设为错误描述，然后调用与正常响应相同的 `recordResponse` 逻辑（存储 + listener）。状态码记为 `0`，响应体记为空字符串。

### 决策 3：非文本响应只记录元数据

`KurilHttpClientResponse.listen()` 判断 `isTextResponse()`，若为 `false` 则：
- `responseBody` 记为空字符串（而非当前的 `'返回结果不支持解析'`）
- `responseSize` 仍正常记录

这样 UI 层不会展示误导性文字，且 size 数据仍有价值。

## Risks / Trade-offs

- **origin 为 null 时的 super 调用**：`KurilHttpOverrides` 持有 `origin`，若 `origin != null` 则委托给 `origin.createHttpClient()`，否则调用 `super.createHttpClient()`，需防止无限递归（当前代码已有此问题：`HttpOverrides.global = null` 临时置空后再调用 `HttpClient(context: context)`，此逻辑保留不动，只在最终返回前包一层 `KurilHttpClient`）。
- **双重 listen 问题**：`transform()` 和 `listen()` 两条路径都调用 `recordResponse`，可能导致同一请求被记录两次。修复方案：在 `KurilHttpInfo` 中增加 `_recorded` flag，`recordResponse` 幂等化。
- **大文件下载内存压力**：非文本响应跳过 body 采集可缓解，但大文本响应仍会将完整内容传入 `recordResponse`，100KB 截断由 `truncateBody` 保障。

## Migration Plan

纯内部实现修复，不改变公共 API 签名，无需用户迁移。升级插件版本后监控自动生效。
