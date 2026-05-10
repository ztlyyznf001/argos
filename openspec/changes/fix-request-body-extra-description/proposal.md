## Why

`ArgosHttpClientRequest` overrides `write()`, `writeln()`, `writeAll()`, and `writeCharCode()` to delegate to `origin` only, without calling `recordParameter()`. When a request body is written through these methods the captured `requestBody` is empty or incomplete, causing the displayed/copied request body to contain unexpected text.

## What Changes

- Override `write()`, `writeln()`, `writeAll()`, and `writeCharCode()` in `ArgosHttpClientRequest` to also record the written content to `httpInfo.request`

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `http-capture-pipeline`: 请求体捕获范围扩展到 `write` 系列方法（原仅通过 `add()` 捕获）

## Impact

- `lib/apm/argos_http_monitor.dart`: 修改 `ArgosHttpClientRequest` 中的 `write`、`writeln`、`writeAll`、`writeCharCode` 方法
