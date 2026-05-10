## Why

生成的 curl 命令中完全缺失请求头（`-H` 参数），根因是 `KurilHttpClientRequest.recordParameter()` 只在写入 body 数据时才赋值 `httpInfo.request.header`，而 GET 等无 body 的请求根本不会调用 `add()`，导致 `header` 永远为 `null`。此外上一版 curl 格式调整将 URL 移至末尾、加了 `-i` 标志，与用户期望的格式（URL 在前、无 `-i`、支持 `--proxy`）不一致。

## What Changes

- **Bug fix：headers 补录**：在 `KurilHttpClientRequest.close()` 中将 `headers` 赋给 `httpInfo.request.header`，确保任何方法（GET/POST/…）都能捕获请求头
- **格式：URL 移至命令开头**：紧接 `curl` 之后输出 URL，与 Charles/Whistle 等工具的导出格式一致
- **格式：去掉 `-i` 标志**：用户期望的格式不含 `-i`
- **格式：`-X METHOD` 换行对齐**：每个参数单独一行续行，与用户期望的格式保持一致
- **新增：`--proxy` 可选参数**：`KurilCurlBuilder.build()` 增加可选 `proxy` 参数，若非空则在末尾追加 `--proxy <proxy>`

## Capabilities

### New Capabilities

_(无新 capability，均为对已有功能的修复与格式调整)_

### Modified Capabilities

- `http-capture-pipeline`：修复 `KurilHttpClientRequest` 请求头捕获逻辑（现有 Requirement 补充 close 时录入 headers 的 Scenario）
- `curl-builder`：更新 cURL 命令格式规范（URL 在前、去掉 `-i`、新增 `--proxy` 参数规则）

## Impact

- `lib/apm/kuril_http_monitor.dart`：`KurilHttpClientRequest.close()` 补录 headers
- `lib/ui/kuril_curl_builder.dart`：调整参数顺序、去掉 `-i`、增加 `proxy` 参数
