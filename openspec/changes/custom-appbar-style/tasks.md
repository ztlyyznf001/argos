## 1. 列表页 AppBar 渐变背景与标题

- [x] 1.1 在 `argos_packet_list_page.dart` 的 `AppBar` 中添加 `flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(...)))` 实现靛蓝→蓝色渐变，同时设置 `backgroundColor: Colors.transparent`
- [x] 1.2 将 AppBar `title` 改为 `Row`：`Icon(Icons.wifi_tethering, size:18, color:Colors.white)` + `SizedBox(width:6)` + `Text('抓包记录')`

## 2. 列表页搜索框样式

- [x] 2.1 将搜索框 `InputDecoration` 的 `filled: true` 和 `fillColor` 移除，改为 `enabledBorder` 和 `focusedBorder` 均使用 `OutlineInputBorder(borderSide: BorderSide(color: Colors.white54, width:1), borderRadius: BorderRadius.circular(8))`

## 3. 详情页 AppBar Method Badge 标题

- [x] 3.1 在 `argos_packet_detail_page.dart` 中添加与列表页一致的 `_methodColor(String method)` 颜色映射函数
- [x] 3.2 将 AppBar `title` 改为 `Row`：左侧 Method Badge Container（语义化颜色背景+文字）+ `SizedBox(width:8)` + `Flexible(child: Text(url, overflow:ellipsis))`
- [x] 3.3 为详情页 AppBar 添加相同的渐变 `flexibleSpace`，与列表页保持一致

## 4. 详情页 TabBar 圆角胶囊指示器

- [x] 4.1 将 `TabBar` 改为带完整样式参数的版本：`indicator: ShapeDecoration(shape: StadiumBorder(), color: Colors.white24)`，`labelColor: Colors.white`，`unselectedLabelColor: Colors.white70`
