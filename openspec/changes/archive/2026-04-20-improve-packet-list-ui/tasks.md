## 1. 列表项视觉升级

- [x] 1.1 在 `kuril_packet_list_page.dart` 中添加 `_methodColor(String method)` 函数，返回 GET/POST/PUT/DELETE/PATCH 对应的语义化 `Color`
- [x] 1.2 在 `_PacketListItem.build` 中将外层 `InkWell + Padding` 替换为 `Card(margin: ..., child: InkWell(...))`，移除下方 `Divider`
- [x] 1.3 更新 Method Badge 样式：背景色使用 `_methodColor().withOpacity(0.12)`，文字颜色使用 `_methodColor()`
- [x] 1.4 添加 `_durationColor(int ms)` 函数：<1000ms 返回 `Colors.grey`，1000-3000ms 返回 `Colors.orange`，>3000ms 返回 `Colors.red`
- [x] 1.5 在 `_PacketListItem` 的耗时 `Text` 中应用 `_durationColor(record.durationMs)` 颜色

## 2. 路由分组 Header 美化

- [x] 2.1 在 `_RouteGroupTileState.build` 的标题行左侧添加一个 `Container(width:3, color: Theme.of(context).primaryColor)` 竖向色块 accent bar
- [x] 2.2 调整 `_RouteGroupTile` 标题行的内边距和字号，使层次感更突出

## 3. 空状态视图优化

- [x] 3.1 将"暂无抓包记录"纯文字 `Center` 替换为图标（`Icons.wifi_off`）+ 文字的列式空状态组件
- [x] 3.2 将"无匹配记录"纯文字 `Center` 替换为图标（`Icons.search_off`）+ 文字的列式空状态组件

## 4. 详情页区块卡片化

- [x] 4.1 在 `kuril_packet_detail_page.dart` 中修改 `_Section.build`：将内容包裹在 `Card(elevation:0, shape: RoundedRectangleBorder(borderRadius:..., side: BorderSide(color: dividerColor)))` 中
- [x] 4.2 同样更新 `_HeaderSection.build` 和 `_BodySection.build`，保持一致的卡片样式
- [x] 4.3 在 `_BodySection` 中将代码块 `Container` 改为使用 `ConstrainedBox(maxHeight: 300)` 包裹 `SingleChildScrollView`，支持内部滚动
- [x] 4.4 加深代码块背景色为 `Colors.grey.shade200`，确保与页面背景有明显区分
