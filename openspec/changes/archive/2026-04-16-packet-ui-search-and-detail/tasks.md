## 1. 列表页搜索与过滤

- [x] 1.1 在 `_KurilPacketListPageState` 中添加 `_searchQuery`（String）和 `_selectedMethod`（String，默认 `'ALL'`）状态，以及 `_filtered` 计算属性（从 `_allRecords` 过滤）
- [x] 1.2 将原 `_records` 拆分为 `_allRecords`（完整数据）和根据条件动态过滤的展示列表，`_load()` 只更新 `_allRecords`
- [x] 1.3 在 `AppBar.bottom` 添加搜索栏 `TextField`，onChange 更新 `_searchQuery` 并 setState
- [x] 1.4 在列表顶部添加 Method chip 行（ALL / GET / POST / PUT / DELETE），点击更新 `_selectedMethod`
- [x] 1.5 过滤逻辑：`_allRecords.where((r) => urlMatch && methodMatch)`，结果为空时展示"无匹配记录"

## 2. 详情页 Tab 重构

- [x] 2.1 将 `KurilPacketDetailPage` 的 `Scaffold` 改为 `DefaultTabController(length: 2)`，`AppBar` 添加 `TabBar(['请求', '响应'])`
- [x] 2.2 将原 `ListView` 内容拆分：请求 Tab 包含 URL/Method/耗时/时间 + Query Params（若有）+ 请求头 + 请求体
- [x] 2.3 响应 Tab 包含：错误卡片（若 `record.error != null`）+ 状态码/大小 + 响应头 + 响应体

## 3. 详情页 Header 展示改进

- [x] 3.1 将 `_headerSection` 中的 `_row(e.key, e.value)` 替换为上下排列组件：key 一行（灰色 11px）+ value 一行（12px 可选文本），去掉固定 80px label 列

## 4. 详情页错误卡片 & Query Params

- [x] 4.1 实现错误卡片 Widget：红色左边框 `Container` + `Text(record.error!)`，置于响应 Tab 顶部（条件渲染）
- [x] 4.2 实现 Query Params 区块：解析 `Uri.parse(record.uri).queryParameters`，非空时在请求 Tab 渲染 key-value 列表

## 5. 验证

- [x] 5.1 运行 `dart analyze lib/` 无新增错误
