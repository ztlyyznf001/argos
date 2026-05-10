## Context

`ArgosCurlBuilder` 是一个单文件单静态方法的工具类，从 `ArgosPacketRecord`（捕获的 HTTP 快照）生成可直接在 shell 中执行的 curl 命令。

当前输出示例：
```
curl -X GET 'https://api.example.com/foo' \
  -H 'content-type: application/json'
```

存在问题：
1. GET 请求输出多余 `-X GET`（curl 默认即为 GET）
2. URL 在命令首位，不符合主流 curl 惯例（官方文档、Postman、curl_logger_dio_interceptor 均将 URL 置于末尾）
3. 请求体原样输出，JSON 无缩进，可读性差
4. 无 `--compressed` 标志，即使请求声明了 gzip 接受能力
5. 无 `-i` 标志，运行 curl 时看不到响应头

## Goals / Non-Goals

**Goals:**
- 生成符合 curl 惯例的命令：`-i`、method 省略逻辑、headers、data、URL（末尾）
- JSON body pretty-print（2 空格缩进）
- `--compressed` 自动追加
- 输出结果与 curl_logger_dio_interceptor 风格对齐

**Non-Goals:**
- 不支持 multipart/form-data 特殊序列化（当前抓包只存文本 body）
- 不修改 `ArgosPacketRecord` 数据结构
- 不引入外部依赖

## Decisions

### 决策 1：参数顺序

生成格式：
```
curl -i \
  [-X METHOD] \
  [-H 'key: value'] \
  [--compressed] \
  [--data-raw 'body'] \
  'URL'
```

顺序参考 curl_logger_dio_interceptor 及 Postman 导出：method → headers → data → URL。`-i` 置于最前作为"全局选项"。

**备选**：不加 `-i` → 但调试时看不到响应头，对监控工具无益。选择默认加 `-i`。

### 决策 2：JSON body pretty-print

尝试 `json.decode` → `JsonEncoder.withIndent('  ').convert`；若解析失败则回退原始字符串。这样 JSON body 可读，非 JSON body（如 form-urlencoded）也不会损坏。

### 决策 3：`--compressed` 检测

检查 `requestHeaders['accept-encoding']`（大小写不敏感）是否包含 `gzip`。若包含则追加 `--compressed`。

### 决策 4：GET 省略 `-X`

`method.toUpperCase() == 'GET'` 时不输出 `-X GET`，与 curl_logger_dio_interceptor 一致。

## Risks / Trade-offs

- **JSON pretty-print 改变 body 内容**：生成的 curl 命令 body 与原始请求 body 格式不同（但语义等价）。对于需要精确复现原始请求的场景，可能造成混淆。→ 接受此 trade-off，可读性更重要；若有精确需求可手动压缩。
- **`-i` 的副作用**：`-i` 会在 stdout 混入响应头，若下游脚本用管道解析响应体可能出错。→ 这是调试工具的命令，不用于生产脚本，接受。
