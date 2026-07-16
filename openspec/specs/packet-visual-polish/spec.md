# packet-visual-polish Specification

## Purpose

定义 Inspector 界面的视觉呈现规范：Method 徽标的语义化配色、列表项与详情页区块的卡片化、慢请求耗时高亮、路由分组 Header 的 accent 装饰、空状态展示，以及响应体代码块的视觉处理。

## Requirements

### Requirement: Method Badge 语义化颜色
`_PacketListItem` 中的 HTTP Method 徽标 SHALL 使用语义化颜色系统：GET=蓝色系、POST=绿色系、PUT=橙色系、DELETE=红色系、PATCH=紫色系，未知方法回退到蓝灰色。徽标背景为对应颜色的低透明度填充，文字为对应颜色。

#### Scenario: GET 请求显示蓝色徽标
- **WHEN** 记录的 method 为 "GET"
- **THEN** Method Badge 背景为蓝色（低透明度），文字为蓝色

#### Scenario: POST 请求显示绿色徽标
- **WHEN** 记录的 method 为 "POST"
- **THEN** Method Badge 背景为绿色（低透明度），文字为绿色

#### Scenario: DELETE 请求显示红色徽标
- **WHEN** 记录的 method 为 "DELETE"
- **THEN** Method Badge 背景为红色（低透明度），文字为红色

#### Scenario: 未知 Method 使用回退颜色
- **WHEN** 记录的 method 不在预定义颜色表中
- **THEN** Method Badge 使用蓝灰色背景和文字

### Requirement: 列表项卡片化展示
`_PacketListItem` SHALL 以 `Card` 组件形式展示，具有圆角、轻微阴影，左右有水平外边距，上下有垂直外边距，替代原有的 `InkWell + Padding + Divider` 方案。

#### Scenario: 列表项呈现为卡片
- **WHEN** 列表中存在抓包记录
- **THEN** 每条记录以独立卡片形式展示，具有圆角和阴影，卡片之间有间距

#### Scenario: 点击卡片导航到详情
- **WHEN** 用户点击某张卡片
- **THEN** 导航到对应记录的详情页（行为与原实现一致）

### Requirement: 慢请求耗时高亮
当请求耗时超过 1000ms 时，列表项中的耗时文字 SHALL 以橙色显示；超过 3000ms 时以红色显示；正常请求保持灰色。

#### Scenario: 正常请求耗时灰色显示
- **WHEN** 记录的 durationMs 小于 1000
- **THEN** 耗时文字为灰色

#### Scenario: 慢请求耗时橙色高亮
- **WHEN** 记录的 durationMs 在 1000 到 3000 之间（含边界）
- **THEN** 耗时文字为橙色

#### Scenario: 极慢请求耗时红色高亮
- **WHEN** 记录的 durationMs 大于 3000
- **THEN** 耗时文字为红色

### Requirement: 路由分组 Header accent 装饰
`_RouteGroupTile` 的分组标题行 SHALL 在左侧显示一个纵向色块（accent bar），作为视觉锚点，与内容区域形成层次区分。

#### Scenario: 分组标题带左侧色块
- **WHEN** 列表中渲染路由分组标题行
- **THEN** 标题行左侧显示一个约 3-4px 宽的竖向色块，颜色为主题 primaryColor 或固定的强调色

### Requirement: 友好的空状态展示
当列表无记录或无匹配记录时，SHALL 展示一个图标加说明文字的空状态视图，替代纯文字提示。空状态的图标与文案 SHALL 依据当前选中的事件类型给出对应提示，MUST NOT 一律假设记录为网络抓包。

#### Scenario: 无记录时展示图标空状态
- **WHEN** 存储中没有任何记录，且事件类型为「全部」
- **THEN** 页面展示一个图标和"暂无记录"文字，垂直居中

#### Scenario: 空状态按事件类型给出对应文案
- **WHEN** 用户选中事件类型「崩溃」，但存储中没有任何崩溃记录
- **THEN** 页面展示与崩溃对应的图标与文案（如"暂无崩溃记录"），而非"暂无抓包记录"

#### Scenario: 无匹配时展示图标空状态
- **WHEN** 搜索或过滤后没有匹配的记录
- **THEN** 页面展示一个图标和"无匹配记录"文字，垂直居中

### Requirement: 详情页区块卡片化
`ArgosPacketDetailPage` 中的各信息区块（基本信息、Query Params、请求头、请求体、响应信息、响应头、响应体）SHALL 各自包裹在 `Card` 中展示，Card 使用 `elevation: 0` 配合边框，区块之间有适当间距。

#### Scenario: 详情页信息区块有卡片边界
- **WHEN** 用户打开抓包记录详情页
- **THEN** 每个信息区块（如"基本信息"、"请求头"等）都有独立的卡片外框，具有圆角和细边框

### Requirement: 响应体代码块视觉优化
`_BodySection` 中的代码块容器 SHALL 使用更明显的背景色（如 `Colors.grey[100]` 加深或使用 `Colors.grey.shade200`），并确保代码文字使用等宽字体，代码块最大高度可滚动。

#### Scenario: 代码块背景与页面背景有明显区分
- **WHEN** 响应体或请求体内容不为空
- **THEN** 代码块容器背景色与页面背景有明显对比，可清楚辨识代码区域边界

#### Scenario: 长代码块可独立滚动
- **WHEN** 响应体内容超过屏幕高度的 40%
- **THEN** 代码块区域限制最大高度并支持内部滚动，不撑开整个页面布局

### Requirement: 暗色模式下的取色与对比度
Inspector 界面的次要文字、分隔线、卡片背景与表面色 SHALL 从 `Theme.of(context).colorScheme` 取值（如 `onSurfaceVariant`、`outlineVariant`、`surfaceContainer`），MUST NOT 硬编码固定灰阶（如 `Colors.grey`），以保证浅色与深色模式下均具备足够对比度。

#### Scenario: 深色模式下次要文字可读
- **WHEN** 宿主应用运行在深色主题下，用户打开 Inspector
- **THEN** 列表项的时间、耗时等次要文字与背景保持足够对比度，不出现灰底灰字

#### Scenario: 卡片与分隔线跟随主题
- **WHEN** 宿主应用在浅色与深色主题之间切换
- **THEN** 卡片背景与分隔线的颜色随 `ColorScheme` 相应变化

### Requirement: 语义色不跟随主题变化
HTTP Method 的语义色（GET 蓝 / POST 绿 / PUT 橙 / DELETE 红 / PATCH 紫）与事件类型的语义色（崩溃红 / 卡顿橙 / 资源青）SHALL 保持固定色相，MUST NOT 从 `ColorScheme` 派生——它们是携带信息的编码而非主题装饰。在深色模式下 MAY 调整其明度以保证对比度，但色相 MUST 保持一致。

#### Scenario: 深色模式下 DELETE 仍为红色系
- **WHEN** 应用切换到深色主题
- **THEN** DELETE 的 Method Badge 仍呈红色系，仅明度按需调整，不因主题而变为其他色相

#### Scenario: 崩溃事件在任何主题下均为红色系
- **WHEN** 列表中展示一条崩溃记录，无论浅色或深色主题
- **THEN** 其图标与类型标签均为红色系，保持"红色 = 危险"的一致语义

### Requirement: 事件类型的图标与标签规范
崩溃、卡顿、资源三类事件 SHALL 各自具备稳定的语义化图标与中文类型标签，在列表项与详情页标题中保持一致，使用户能够一眼区分事件类型。

#### Scenario: 三类事件具备可区分的图标
- **WHEN** 列表中同时存在崩溃、卡顿、资源三类记录
- **THEN** 每类记录展示各自不同的图标与类型标签（崩溃 / 卡顿 / 资源），彼此可一眼区分

#### Scenario: 列表与详情页的图标标签一致
- **WHEN** 用户从列表点击一条卡顿记录进入详情页
- **THEN** 详情页标题栏展示的图标与类型标签与列表项中的一致
