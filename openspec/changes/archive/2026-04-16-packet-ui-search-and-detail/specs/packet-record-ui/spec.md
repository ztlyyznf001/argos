## ADDED Requirements

### Requirement: 列表页 URL 关键词搜索
系统 SHALL 在 `KurilPacketListPage` 顶部提供搜索栏，支持按 URL 关键词实时过滤抓包记录。

#### Scenario: 输入关键词实时过滤
- **WHEN** 用户在搜索栏输入文本
- **THEN** 列表立即更新，只显示 URI 中包含该文本的记录（大小写不敏感），无需点击搜索按钮

#### Scenario: 清空搜索恢复全量
- **WHEN** 用户清空搜索栏文本
- **THEN** 列表恢复展示所有记录

#### Scenario: 过滤后无结果
- **WHEN** 搜索关键词在所有记录中均无匹配
- **THEN** 列表区域展示"无匹配记录"提示文字，不显示列表

### Requirement: 列表页 Method 快捷过滤
系统 SHALL 在列表页提供 Method 过滤选项（至少 ALL / GET / POST），可与搜索栏组合使用。

#### Scenario: 选择 Method 过滤
- **WHEN** 用户点击某个 Method chip（如 POST）
- **THEN** 列表只显示该 Method 的记录（在当前搜索关键词基础上叠加过滤）

#### Scenario: 选择 ALL 恢复
- **WHEN** 用户点击 ALL chip
- **THEN** Method 过滤取消，列表仅受搜索关键词约束

### Requirement: 详情页请求/响应 Tab 分离
系统 SHALL 将 `KurilPacketDetailPage` 的内容分为"请求"和"响应"两个 Tab，分别展示对应信息。

#### Scenario: 默认显示请求 Tab
- **WHEN** 用户打开某条记录的详情页
- **THEN** 默认选中"请求" Tab，展示 URL、Method、耗时、时间、Query Params（若有）、请求头、请求体

#### Scenario: 切换到响应 Tab
- **WHEN** 用户点击"响应" Tab
- **THEN** 展示状态码、响应大小、响应头、响应体

### Requirement: 详情页 Header 自适应展示
系统 SHALL 将请求头和响应头的每个 key-value 以上下排列方式展示，key 独占一行（灰色），value 在下一行全宽展示，不截断。

#### Scenario: 长 Header key 完整显示
- **WHEN** 请求头包含较长的 key（如 `x-request-package-sign-version`）
- **THEN** key 文字完整展示，不截断，value 在其下方另起一行

### Requirement: 详情页错误请求醒目展示
系统 SHALL 在错误请求（`record.error != null`）的响应 Tab 顶部展示一个红色警告卡片，内容为错误描述文字。

#### Scenario: 错误请求展示警告卡片
- **WHEN** 用户打开一条 `error` 字段非空的抓包记录并切换到响应 Tab
- **THEN** 响应 Tab 顶部出现红色边框卡片，展示 `record.error` 的内容

#### Scenario: 正常请求无警告卡片
- **WHEN** 用户打开一条 `error` 为 null 的正常抓包记录
- **THEN** 响应 Tab 中无错误卡片

### Requirement: 详情页 Query Params 区块
系统 SHALL 在请求 Tab 中解析 URL 的 query string，以 key-value 列表形式展示各参数；若无 query params 则不展示该区块。

#### Scenario: 有 Query Params 时展示
- **WHEN** 请求 URL 包含 query string（如 `?page=1&size=20`）
- **THEN** 请求 Tab 中展示"Query Params"区块，每个参数一行显示 key 和 value

#### Scenario: 无 Query Params 时隐藏
- **WHEN** 请求 URL 不包含 query string
- **THEN** 请求 Tab 中不展示"Query Params"区块
