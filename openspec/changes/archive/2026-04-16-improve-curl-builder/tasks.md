## 1. KurilCurlBuilder 重写

- [x] 1.1 添加 `dart:convert` import（用于 JSON pretty-print）
- [x] 1.2 将 URL 从命令开头移到末尾，调整 `buf.write` 顺序
- [x] 1.3 在命令开头添加 `-i` 标志：`curl -i`
- [x] 1.4 GET 请求省略 `-X GET`：仅当 `method.toUpperCase() != 'GET'` 时输出 `-X METHOD`
- [x] 1.5 `--compressed` 检测：遍历 `requestHeaders` 找 `accept-encoding`（大小写不敏感），若包含 `gzip` 则在 headers 之后追加 `--compressed`
- [x] 1.6 JSON body pretty-print：检测 `Content-Type` 包含 `json` 时，`json.decode` → `JsonEncoder.withIndent('  ').convert`；失败则回退原始字符串

## 2. 验证

- [x] 2.1 对 GET 请求确认无 `-X GET`，URL 在末尾
- [x] 2.2 对含 `Accept-Encoding: gzip` 的请求确认有 `--compressed`
- [x] 2.3 对 JSON body 确认输出 pretty-print 格式
- [x] 2.4 运行 `dart analyze lib/` 无新增错误
