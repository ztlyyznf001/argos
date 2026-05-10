## Why

`ArgosCurlBuilder.build()` 生成的 cURL 命令存在多处不规范之处：GET 请求输出了多余的 `-X GET`、URL 放在首位不符合主流 curl 惯例、请求体直接拼接原始字符串而不做 JSON 格式化、缺少 `--compressed` 标志等，导致生成的命令可读性差且在部分 shell 环境中可能运行不符合预期。

## What Changes

- **省略 GET 的 `-X` 参数**：curl 默认方法为 GET，无需显式声明
- **URL 移至命令末尾**：符合标准 curl 用法，与 curl 官方文档和主流工具（如 curl_logger_dio_interceptor）保持一致
- **JSON 响应体格式化输出**：当 Content-Type 为 `application/json` 时，对请求体做 pretty-print（缩进 2 空格）
- **`--compressed` 标志**：当请求头 `Accept-Encoding` 包含 `gzip` 时自动追加
- **`-i` 标志**：在生成的命令中包含 `-i`，使 curl 运行时也输出响应头，方便调试对比
- **换行缩进格式统一**：每个参数独占一行，以 `\` 续行，缩进 2 空格（与现有格式一致，微调 `-i` 位置）

## Capabilities

### New Capabilities

- `curl-builder`: cURL 命令构建规则——包括方法省略逻辑、参数顺序、JSON 格式化、compressed 标志、响应头标志

### Modified Capabilities

- `packet-record-ui`: 详情页"复制 cURL"按钮调用 `ArgosCurlBuilder.build()` 的产出结果发生变化（格式更规范），需更新 cURL 格式规范示例

## Impact

- `lib/ui/argos_curl_builder.dart`：核心修改，`ArgosCurlBuilder.build()` 静态方法
- `openspec/specs/packet-record-ui/spec.md`：更新 cURL 格式示例（delta）
- 无新增依赖，公共 API 签名不变
