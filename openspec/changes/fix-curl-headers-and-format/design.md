## Context

**Header 捕获 bug 根因**

`ArgosHttpClientRequest` 用 `recordParameter(data)` 在写 body 时顺带记录 headers：
```dart
void recordParameter(List<int> data) {
  httpInfo?.request.header = headers;  // 只在 add() 被调用时执行
  httpInfo?.request.add(encoding.decode(data));
}
```
GET 请求不调用 `add()`，所以 `httpInfo.request.header` 始终为 `null`，`ArgosHttpInfo.toJson()` 里 `headersToMap(null)` 返回空 Map，curl 命令生成时无任何 `-H` 参数。

**Curl 格式期望**

用户期望的格式（参考自 Charles/Whistle）：
```
curl 'URL' \
-X METHOD \
-H 'Key: Value' \
--compressed \
--data-raw 'body' \
--proxy http://localhost:9091
```

与上一版差异：URL 在最前、无 `-i`、`--proxy` 可选追加在最后。

## Goals / Non-Goals

**Goals:**
- 所有 HTTP 方法都能正确捕获请求头
- curl 格式与 Charles/Whistle 导出风格对齐
- `build()` 支持可选 proxy 参数

**Non-Goals:**
- 不改变 `ArgosPacketRecord` 数据结构
- 不修改 `HttpRequest` model（`header` 字段已存在）

## Decisions

### 决策 1：在 `close()` 中补录 headers

`close()` 是请求生命周期的终点，此时 `headers` 已确定（所有 `set()`/`add()` 已完成）。只需在 `close()` 的第一行加：
```dart
httpInfo?.request.header = headers;
```
`recordParameter` 中的赋值保留（body 场景仍由其覆盖），`close()` 中的赋值先于 body 记录、也作为无 body 场景的兜底。

### 决策 2：curl 参数顺序

```
curl 'URL' [-X METHOD] [-H ...] [--compressed] [--data-raw '...'] [--proxy ...]
```

GET 省略 `-X` 逻辑不变。`--proxy` 作为最后一个参数，与 curl 命令行习惯一致（选项可放任意位置，但末尾最直观）。

### 决策 3：`build()` 签名增加可选 proxy

```dart
static String build(ArgosPacketRecord record, {String? proxy})
```

调用方可选传入，不传时行为与之前一致，无破坏性变更。

## Risks / Trade-offs

- **`close()` 中赋值时机**：`headers` 在 `close()` 时已冻结（dart:io 不允许在 close 后再 set header），所以此时读取是安全且完整的。
- **双重赋值**：`recordParameter` 和 `close()` 都会赋值 `header`，`close()` 先执行（在 `origin.close()` 之前），`recordParameter` 后执行（由 `add()` 触发）。两次赋值的内容相同，无副作用。
