## MODIFIED Requirements

### Requirement: 抓包记录列表页
系统 SHALL 提供 `ArgosPacketListPage` Widget，展示所有历史记录的摘要列表。列表为混合事件流，可能包含网络、崩溃、卡顿、资源四类记录。网络记录以 Card 形式展示，显示：带语义化颜色的 Method Badge、URL（缩略）、状态码 Chip、响应体大小、耗时（慢请求高亮）、请求时间（相对时间与绝对时间并列）。非网络记录按其 `kind` 展示对应的语义化图标、类型标签与事件摘要。

#### Scenario: 展示记录列表
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** 页面加载所有记录并以卡片列表形式展示；网络记录显示 Method Badge（语义化颜色）、URL（缩略）、状态码、响应体大小、耗时、请求时间

#### Scenario: 网络记录展示响应体大小
- **WHEN** 列表渲染一条网络记录
- **THEN** 该记录展示其响应体大小（`responseSize`），以人类可读单位（如 `1.2 KB`）呈现

#### Scenario: 时间同时展示相对与绝对形式
- **WHEN** 列表渲染任意一条记录的时间
- **THEN** 该记录同时展示相对时间与绝对时刻（如 `2 分钟前 · 14:03:22`），便于判断新鲜度并与日志对齐

#### Scenario: 混合事件流中展示非网络记录
- **WHEN** 列表中存在崩溃、卡顿或资源记录
- **THEN** 这些记录以对应 `kind` 的语义化图标、类型标签与事件摘要展示，而非套用 HTTP 的 Method/状态码/耗时结构

#### Scenario: 无记录时展示空状态
- **WHEN** 存储中没有任何记录
- **THEN** 页面展示图标加说明文字的空状态视图，垂直居中

#### Scenario: 点击记录进入详情
- **WHEN** 用户点击列表中的某一条记录卡片
- **THEN** 页面导航到 `ArgosPacketDetailPage`，展示该条记录的详细信息

### Requirement: 抓包记录详情页
系统 SHALL 提供 `ArgosPacketDetailPage` Widget，并依据 `ArgosPacketRecord.kind` 分派到与该事件类型语义匹配的详情展示：`network` 展示请求与响应双 Tab；`crash`、`jank`、`resource` 各自展示专属的单页视图。系统 SHALL NOT 为非网络事件呈现「请求 / 响应」Tab。

#### Scenario: 网络记录展示请求信息
- **WHEN** 用户打开一条 `kind == 'network'` 记录的详情页
- **THEN** 页面在「请求」Tab 展示：完整 URL、HTTP Method、请求头（所有 key-value）、请求体（原始文本）

#### Scenario: 网络记录展示响应信息
- **WHEN** 用户打开一条 `kind == 'network'` 记录的详情页
- **THEN** 页面在「响应」Tab 展示：状态码、响应头（所有 key-value）、响应体（原始文本，若截断则显示截断标注）、响应大小、耗时（ms）

#### Scenario: 响应体格式化
- **WHEN** 响应 Content-Type 包含 `json`
- **THEN** 系统尝试对响应体进行 JSON 格式化展示（缩进对齐），若格式化失败则回退到原始文本

#### Scenario: 崩溃记录展示异常与堆栈
- **WHEN** 用户打开一条 `kind == 'crash'` 记录的详情页
- **THEN** 页面展示异常消息、完整堆栈（可复制）与发生时所在路由，且不展示「请求 / 响应」Tab

#### Scenario: 卡顿记录展示帧耗时拆分
- **WHEN** 用户打开一条 `kind == 'jank'` 记录的详情页
- **THEN** 页面展示丢帧数、区间总耗时、最大单帧耗时，以及 `buildDuration`（UI 线程）与 `rasterDuration`（Raster 线程）的拆分，且不展示「请求 / 响应」Tab

#### Scenario: 资源记录展示内存采样
- **WHEN** 用户打开一条 `kind == 'resource'` 记录的详情页
- **THEN** 页面展示当前 RSS、峰值 RSS 与采样时刻；CPU 不可得时该字段留空而非显示占位值；且不展示「请求 / 响应」Tab

#### Scenario: 详情页标题按事件类型分派
- **WHEN** 用户打开一条非网络记录的详情页
- **THEN** 标题栏展示该事件类型的徽标与事件摘要，而非空白的 HTTP Method 徽标
