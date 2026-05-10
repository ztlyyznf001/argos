## 1. KurilHttpOverrides 接线修复

- [x] 1.1 修改 `KurilHttpOverrides.createHttpClient()`：在返回前将底层 `HttpClient` 包装为 `KurilHttpClient(raw)`
- [x] 1.2 验证 `findProxy` 和 `badCertificateCallback` 在包装后仍正确作用于 `raw`（origin 不为 null 的分支同样包装）

## 2. 错误捕获

- [x] 2.1 在 `KurilHttpClient.monitor()` 的 `catchError` 中将 `httpInfo.error` 设为错误描述字符串
- [x] 2.2 错误发生时调用 `recordResponse(0, '', ...)` 触发存储和 listener（需先设置 `httpInfo.error`）
- [x] 2.3 `KurilHttpInfo.response.endTimestamp` 在错误路径中也写入当前时间戳

## 3. recordResponse 幂等化

- [x] 3.1 在 `KurilHttpInfo` 中增加 `bool _recorded = false` 标记
- [x] 3.2 `recordResponse` 入口检查 `_recorded`，若已为 `true` 则直接返回，否则置 `true` 后继续

## 4. 非文本响应处理

- [x] 4.1 将 `listen()` 中 `isTextResponse() == false` 时的 `recordResponse` 调用改为 `responseBody = ''`（移除"返回结果不支持解析"字符串）
- [x] 4.2 `transform()` 中同样的非文本分支做相同修改

## 5. KurilPacketRecord 错误字段

- [x] 5.1 在 `KurilPacketRecord` 和 `KurilHttpInfo.toJson()` 中增加 `error` 字段（nullable String）
- [x] 5.2 `KurilPacketRecord.fromJson()` 解析 `error` 字段
- [x] 5.3 更新 `KurilPacketStorage.append()` 确保错误记录参与正常存储和淘汰逻辑（无需额外改动，验证即可）

## 6. 验证

- [ ] 6.1 在 `list_example.dart` 发起真实请求，确认 `KurilPacketListPage` 能展示该条记录
- [ ] 6.2 断网场景下发起请求，确认错误记录出现在列表中且 `responseCode = 0`
- [ ] 6.3 发起图片请求，确认列表记录 `responseBody` 为空而非乱码

