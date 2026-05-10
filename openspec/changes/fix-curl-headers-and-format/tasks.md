## 1. Bug Fix：请求头捕获

- [x] 1.1 在 `ArgosHttpClientRequest.close()` 首行添加 `httpInfo?.request.header = headers`，在调用 `origin.close()` 之前完成赋值

## 2. curl 格式调整

- [x] 2.1 将 URL 移至命令开头：`curl '${record.uri}'`（去掉末尾的 URL 输出）
- [x] 2.2 去掉 `-i` 标志（`buf.write('curl -i')` 改为 `buf.write("curl '${record.uri}'")`）
- [x] 2.3 在 `build()` 签名中添加可选命名参数 `{String? proxy}`
- [x] 2.4 在命令末尾追加 `--proxy`：若 `proxy` 非空则输出 ` \\\n--proxy $proxy`

## 3. 验证

- [x] 3.1 用 dart 脚本验证 GET 请求无 `-X GET`、URL 在首位、无 `-i`
- [x] 3.2 用 dart 脚本验证 `proxy` 参数传入时末尾有 `--proxy`，不传时无
- [x] 3.3 运行 `dart analyze lib/` 无新增错误
