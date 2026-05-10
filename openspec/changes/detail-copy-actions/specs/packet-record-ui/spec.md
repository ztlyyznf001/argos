## MODIFIED Requirements

### Requirement: 复制请求为 cURL 命令
详情页 SHALL 提供复制 cURL 图标按钮（`IconButton`），将当前抓包记录转换为等价的 cURL 命令字符串并写入系统剪贴板。

#### Scenario: 生成 cURL 命令
- **WHEN** 用户在详情页点击复制 cURL 图标按钮
- **THEN** 系统根据该记录的 Method、URL、请求头、请求体生成标准 cURL 命令字符串，写入剪贴板，并显示短暂的成功提示（SnackBar）

#### Scenario: cURL 按钮以图标形式展示
- **WHEN** 用户打开详情页
- **THEN** AppBar 右侧显示复制图标按钮（`Icons.copy`），悬停时显示"复制 cURL" tooltip，不以纯文本按钮形式展示

#### Scenario: cURL 命令包含请求头
- **WHEN** 请求包含一个或多个请求头
- **THEN** 生成的 cURL 命令中每个请求头以 `-H 'Key: Value'` 形式追加

#### Scenario: cURL 命令包含请求体
- **WHEN** 请求体不为空（POST/PUT/PATCH 等）
- **THEN** 生成的 cURL 命令中请求体以 `--data-raw '...'` 形式追加

#### Scenario: GET 请求无请求体
- **WHEN** 请求方法为 GET 且无请求体
- **THEN** 生成的 cURL 命令中不包含 `--data-raw` 参数，也不包含 `-X GET`

## ADDED Requirements

### Requirement: 复制响应体
详情页 SHALL 在响应 Tab 的响应体区块标题旁提供复制图标按钮，点击后将当前展示的响应体内容（格式化后）写入系统剪贴板。

#### Scenario: 点击复制响应体
- **WHEN** 用户在响应 Tab 点击响应体区块的复制图标按钮
- **THEN** 响应体的格式化内容（JSON pretty-print 或原始文本）被写入剪贴板，显示"已复制响应体" SnackBar 提示

#### Scenario: 响应体为空时复制按钮仍可点击
- **WHEN** 响应体为空字符串
- **THEN** 复制按钮可见但点击后复制空内容，SnackBar 正常显示
