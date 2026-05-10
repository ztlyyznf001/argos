## Why

当前 `KurilHttpOverrides.createHttpClient()` 返回的是原始 `HttpClient`，并未包裹成 `KurilHttpClient`，导致请求/响应数据实际上**从未被拦截录制**。`KurilHttpClient` 类已存在但游离于主流程之外，整个监控链路断路。

## What Changes

- **修复 HttpOverrides 接线**：`createHttpClient` 返回 `KurilHttpClient(origin)` 而非 `origin`，将监控包装器接入真实调用链
- **完善错误捕获**：请求失败（网络错误、超时、DNS 失败）时将错误信息记录到 `KurilHttpInfo.error` 并上报/存储
- **请求耗时记录**：在 `KurilHttpInfo` 中补全 `endTimestamp`，使 `durationMs` 能正确反映真实耗时
- **Host 白名单过滤**：只有在 `hostWhiteList` 中的域名才触发存储和 listener 回调，精准控制采集范围
- **Content-Type 过滤优化**：非文本响应（图片、二进制）标记 `responseBody` 为空而不是写入错误提示字符串

## Capabilities

### New Capabilities

- `http-capture-pipeline`: HTTP 请求拦截链路的完整实现——从 `HttpOverrides` 创建 `KurilHttpClient`，到捕获请求头/请求体/响应头/响应体/状态码/耗时/错误，最终写入存储并触发 listener

### Modified Capabilities

- `packet-storage`: 增加错误场景的存储要求——当请求失败（`KurilHttpInfo.error != null`）时也应持久化该条记录

## Impact

- `lib/apm/kuril_http_monitor.dart`：核心修改，`KurilHttpOverrides`、`KurilHttpClient`、`KurilHttpClientRequest`、`KurilHttpClientResponse`
- `lib/model/kuril_http_info_model.dart`：`KurilHttpInfo` 补全耗时字段
- `openspec/specs/packet-storage/spec.md`：新增错误记录存储场景（delta）
- 无新增外部依赖，不影响公共 API 签名
