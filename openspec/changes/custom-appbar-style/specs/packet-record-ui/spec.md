## MODIFIED Requirements

### Requirement: 抓包记录列表页
系统 SHALL 提供 `ArgosPacketListPage` Widget，展示所有历史抓包记录的摘要列表。每条记录以 Card 形式展示，显示：带语义化颜色的 Method Badge、URL（缩略）、状态码 Chip、耗时（慢请求高亮）、请求时间。AppBar 使用靛蓝到蓝色渐变背景，标题区显示网络图标与文字，搜索框使用白色描边样式。

#### Scenario: 展示记录列表
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** 页面从 MMKV 加载所有记录并以卡片列表形式展示，每条显示：Method Badge（语义化颜色）、URL（缩略）、状态码、耗时、请求时间

#### Scenario: 无记录时展示空状态
- **WHEN** MMKV 中没有任何抓包记录
- **THEN** 页面展示图标加"暂无抓包记录"文字的空状态视图，垂直居中

#### Scenario: 点击记录进入详情
- **WHEN** 用户点击列表中的某一条记录卡片
- **THEN** 页面导航到 `ArgosPacketDetailPage`，展示该条记录的详细信息
