## Why

列表页和详情页的 AppBar 目前使用 Material 默认样式，视觉上单调、无品牌感，与刚刚升级的卡片化列表整体风格不协调。自定义 AppBar 可以让整体页面更有设计感。

## What Changes

- **列表页 AppBar**：替换为渐变背景（深蓝到靛蓝），标题区加入网络图标，搜索框改为白色描边圆角风格，抓包开关和清空按钮视觉升级
- **详情页 AppBar**：标题区内嵌 Method Badge（使用与列表一致的语义化颜色）+ URL 路径，TabBar 使用自定义指示器样式（圆角胶囊）
- **提取公共渐变常量**：两个页面共用同一套渐变色，避免重复定义

## Capabilities

### New Capabilities

- `appbar-visual-style`: 定义两个抓包页面 AppBar 的视觉规范，包括渐变背景、标题布局、搜索框样式和 TabBar 指示器

### Modified Capabilities

- `packet-record-ui`: AppBar 外观约束（列表页渐变 AppBar、详情页 Method Badge 标题、TabBar 样式）

## Impact

- `lib/ui/argos_packet_list_page.dart`：修改 `AppBar` 构建逻辑，搜索框样式
- `lib/ui/argos_packet_detail_page.dart`：修改 `AppBar` 标题和 `TabBar` 样式
- 不涉及功能逻辑、数据模型或外部依赖变更
