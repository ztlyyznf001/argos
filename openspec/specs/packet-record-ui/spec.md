## ADDED Requirements

### Requirement: 抓包记录列表页
系统 SHALL 提供 `ArgosPacketListPage` Widget，展示所有历史抓包记录的摘要列表。每条记录以 Card 形式展示，显示：带语义化颜色的 Method Badge、URL（缩略）、状态码 Chip、耗时（慢请求高亮）、请求时间。

#### Scenario: 展示记录列表
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** 页面从 MMKV 加载所有记录并以卡片列表形式展示，每条显示：Method Badge（语义化颜色）、URL（缩略）、状态码、耗时、请求时间

#### Scenario: 无记录时展示空状态
- **WHEN** MMKV 中没有任何抓包记录
- **THEN** 页面展示图标加"暂无抓包记录"文字的空状态视图，垂直居中

#### Scenario: 点击记录进入详情
- **WHEN** 用户点击列表中的某一条记录卡片
- **THEN** 页面导航到 `ArgosPacketDetailPage`，展示该条记录的详细信息

### Requirement: 抓包记录详情页
系统 SHALL 提供 `ArgosPacketDetailPage` Widget，展示单条抓包记录的完整请求与响应信息。

#### Scenario: 展示请求信息
- **WHEN** 用户打开某条抓包记录的详情页
- **THEN** 页面展示：完整 URL、HTTP Method、请求头（所有 key-value）、请求体（原始文本）

#### Scenario: 展示响应信息
- **WHEN** 用户打开某条抓包记录的详情页
- **THEN** 页面展示：状态码、响应头（所有 key-value）、响应体（原始文本，若截断则显示截断标注）、响应大小、耗时（ms）

#### Scenario: 响应体格式化
- **WHEN** 响应 Content-Type 包含 `json`
- **THEN** 系统尝试对响应体进行 JSON 格式化展示（缩进对齐），若格式化失败则回退到原始文本

### Requirement: 清空所有记录操作
列表页 SHALL 提供清空所有抓包记录的操作入口。

#### Scenario: 用户清空记录
- **WHEN** 用户在列表页点击"清空"按钮并确认操作
- **THEN** 调用 `ArgosPacketStorage.clear()` 清空 MMKV 中的记录，列表页刷新为空状态

#### Scenario: 用户取消清空
- **WHEN** 用户点击"清空"按钮后在确认弹窗中取消
- **THEN** 不执行清空操作，列表保持不变

### Requirement: 实时刷新列表
列表页 SHALL 在打开时从存储重新加载数据，确保展示最新记录。

#### Scenario: 页面重新进入时刷新
- **WHEN** 用户从详情页返回列表页
- **THEN** 列表重新从 MMKV 读取数据并刷新展示（不需要手动下拉刷新）

### Requirement: 复制请求为 cURL 命令
详情页 SHALL 提供"复制 cURL"按钮，将当前抓包记录转换为等价的 cURL 命令字符串并写入系统剪贴板。

#### Scenario: 生成 cURL 命令
- **WHEN** 用户在详情页点击"复制 cURL"按钮
- **THEN** 系统根据该记录的 Method、URL、请求头、请求体生成标准 cURL 命令字符串（格式见下），写入剪贴板，并显示短暂的成功提示（SnackBar）

#### Scenario: cURL 命令包含请求头
- **WHEN** 请求包含一个或多个请求头
- **THEN** 生成的 cURL 命令中每个请求头以 `-H 'Key: Value'` 形式追加

#### Scenario: cURL 命令包含请求体
- **WHEN** 请求体不为空（POST/PUT/PATCH 等）
- **THEN** 生成的 cURL 命令中请求体以 `--data-raw '...'` 形式追加

#### Scenario: GET 请求无请求体
- **WHEN** 请求方法为 GET 且无请求体
- **THEN** 生成的 cURL 命令中不包含 `--data-raw` 参数，也不包含 `-X GET`

生成格式示例：
```
curl -i \
  -X POST \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer token123' \
  --compressed \
  --data-raw '{
    "user": "foo",
    "pass": "bar"
  }' \
  'https://example.com/api/login'
```

### Requirement: 列表页 URL 关键词搜索
系统 SHALL 在 `ArgosPacketListPage` 顶部提供搜索栏，支持按 URL 关键词实时过滤抓包记录。

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
系统 SHALL 将 `ArgosPacketDetailPage` 的内容分为"请求"和"响应"两个 Tab，分别展示对应信息。

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

### Requirement: 列表页路由分组展开列表
`ArgosPacketListPage` SHALL 将记录以按路由分组的 `ExpansionTile` 列表形式展示（见 `packet-route-grouping` spec），替代原有的平铺列表。搜索栏和 Method 过滤器在分组视图下仍然生效。

#### Scenario: 初始化时所有分组默认展开
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** 所有路由分组默认处于展开状态，可直接看到每组的记录列表

#### Scenario: 用户折叠/展开某个分组
- **WHEN** 用户点击某个路由分组标题
- **THEN** 该分组在展开和折叠之间切换，其他分组状态不变

#### Scenario: 记录刷新后分组重新计算
- **WHEN** 用户从详情页返回列表页（数据重新加载）
- **THEN** 分组根据最新记录的 routeName 集合重新生成，各分组展开状态重置为默认展开

### Requirement: 列表页抓包开关按钮
`ArgosPacketListPage` AppBar SHALL 提供一个图标按钮，实时显示并控制 `ArgosManager.instance.captureEnabled` 状态。

#### Scenario: 开关图标反映当前状态
- **WHEN** 用户打开 `ArgosPacketListPage`
- **THEN** AppBar 显示开关图标：抓包开启时显示暂停图标，关闭时显示录制图标

#### Scenario: 点击开关切换抓包状态
- **WHEN** 用户点击 AppBar 中的开关图标
- **THEN** `ArgosManager.instance.captureEnabled` 取反，图标随之更新
