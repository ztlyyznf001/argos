## Why

抓包记录的列表页和详情页目前功能完整，但视觉设计较为朴素——纯文字行、无层次感、缺少视觉引导，在调试场景下难以快速扫描和定位目标请求。提升页面颜值可以明显改善开发者的使用体验。

## What Changes

- **列表项卡片化**：每条抓包记录从平铺行升级为带圆角、阴影的 Card，增加视觉层次
- **Method Badge 色彩升级**：GET/POST/PUT/DELETE/PATCH 使用各自专属颜色背景徽标，一眼识别
- **状态码视觉强化**：状态码以更醒目的 Chip 样式展示，2xx/3xx/4xx/5xx 色系分明
- **路由分组 Header 美化**：分组标题行增加左侧色块装饰、更清晰的计数 Badge
- **耗时可视化**：慢请求（>1s）耗时文字以橙色/红色高亮，快速请求保持灰色
- **空状态插图**：无记录和无匹配时展示更友好的图标 + 说明文字
- **详情页区块卡片化**：请求/响应 Tab 内各信息区块包裹在 Card 中，间距更舒适
- **响应体代码块优化**：代码块使用带明显背景色的容器，字体更清晰，支持更好的滚动体验

## Capabilities

### New Capabilities

- `packet-visual-polish`: 定义抓包页面（列表页 + 详情页）的视觉设计规范，包括颜色、排版、组件样式要求

### Modified Capabilities

- `packet-record-ui`: 在现有功能需求基础上，补充视觉呈现约束（Method Badge 色彩、状态码 Chip 样式、慢请求高亮、空状态展示规范）

## Impact

- `lib/ui/kuril_packet_list_page.dart`：重构 `_PacketListItem`、`_RouteGroupTile` 的视觉样式
- `lib/ui/kuril_packet_detail_page.dart`：重构 `_Section`、`_BodySection`、`_InfoRow` 等共享 Widget 样式
- 不涉及存储、数据模型、网络拦截逻辑变更
- 不引入新的外部依赖
