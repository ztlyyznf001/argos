## ADDED Requirements

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
当列表无记录或无匹配记录时，SHALL 展示一个图标（`Icons.wifi_off` 或类似）加说明文字的空状态视图，替代纯文字提示。

#### Scenario: 无记录时展示图标空状态
- **WHEN** 存储中没有任何抓包记录
- **THEN** 页面展示一个灰色图标和"暂无抓包记录"文字，垂直居中

#### Scenario: 无匹配时展示图标空状态
- **WHEN** 搜索或 Method 过滤后没有匹配的记录
- **THEN** 页面展示一个灰色图标和"无匹配记录"文字，垂直居中

### Requirement: 详情页区块卡片化
`KurilPacketDetailPage` 中的各信息区块（基本信息、Query Params、请求头、请求体、响应信息、响应头、响应体）SHALL 各自包裹在 `Card` 中展示，Card 使用 `elevation: 0` 配合边框，区块之间有适当间距。

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
