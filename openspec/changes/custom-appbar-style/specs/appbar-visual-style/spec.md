## ADDED Requirements

### Requirement: 列表页 AppBar 渐变背景
`ArgosPacketListPage` 的 AppBar SHALL 使用从 `Colors.indigo.shade700` 到 `Colors.blue.shade600` 的线性渐变作为背景，通过 `flexibleSpace` 实现。

#### Scenario: 列表页顶部显示渐变背景
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** AppBar 背景呈现靛蓝到蓝色的渐变效果，而非纯色

### Requirement: 列表页 AppBar 标题带图标
`ArgosPacketListPage` 的 AppBar 标题 SHALL 由一个小图标（`Icons.wifi_tethering`）和"抓包记录"文字并排组成。

#### Scenario: 标题区显示图标与文字
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** AppBar 标题区左侧显示网络图标，右侧紧跟"抓包记录"文字

### Requirement: 列表页搜索框描边样式
`ArgosPacketListPage` 搜索框 SHALL 使用白色半透明描边（`Colors.white54`）的 `OutlineInputBorder`，去掉 `filled` 背景，保持整体与渐变 AppBar 协调。

#### Scenario: 搜索框呈现描边风格
- **WHEN** 用户看到列表页搜索框
- **THEN** 搜索框有白色半透明边框，无填充背景色，圆角与渐变背景融合自然

### Requirement: 详情页 AppBar Method Badge 标题
`ArgosPacketDetailPage` 的 AppBar 标题 SHALL 由 Method Badge（语义化颜色 Chip 样式）和 URL 路径文字并排组成，替代原纯文字标题。

#### Scenario: 详情页标题显示 Method Badge
- **WHEN** 用户打开某条抓包记录的详情页
- **THEN** AppBar 标题区左侧显示带语义化颜色的 Method Badge，右侧显示 URL 路径（截断）

### Requirement: 详情页 TabBar 圆角胶囊指示器
`ArgosPacketDetailPage` 的 TabBar SHALL 使用圆角胶囊形状的 indicator（`ShapeDecoration` + `StadiumBorder`），填充颜色为 `Colors.white24`，未选中标签颜色 `Colors.white70`，选中标签颜色 `Colors.white`。

#### Scenario: TabBar 选中态显示胶囊背景
- **WHEN** 用户切换请求/响应 Tab
- **THEN** 当前选中的 Tab 背景为白色半透明圆角胶囊，未选中 Tab 文字为白色70%透明度
