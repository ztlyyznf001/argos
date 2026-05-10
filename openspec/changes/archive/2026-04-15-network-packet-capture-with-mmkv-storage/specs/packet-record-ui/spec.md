## ADDED Requirements

### Requirement: 抓包记录列表页
系统 SHALL 提供 `KurilPacketListPage` Widget，展示所有历史抓包记录的摘要列表。

#### Scenario: 展示记录列表
- **WHEN** 用户打开 `KurilPacketListPage`
- **THEN** 页面从 MMKV 加载所有记录并以列表形式展示，每条显示：Method、URL（缩略）、状态码、耗时、请求时间

#### Scenario: 无记录时展示空状态
- **WHEN** MMKV 中没有任何抓包记录
- **THEN** 页面展示空状态提示（如"暂无抓包记录"），不显示列表

#### Scenario: 点击记录进入详情
- **WHEN** 用户点击列表中的某一条记录
- **THEN** 页面导航到 `KurilPacketDetailPage`，展示该条记录的详细信息

### Requirement: 抓包记录详情页
系统 SHALL 提供 `KurilPacketDetailPage` Widget，展示单条抓包记录的完整请求与响应信息。

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
- **THEN** 调用 `KurilPacketStorage.clear()` 清空 MMKV 中的记录，列表页刷新为空状态

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
- **THEN** 生成的 cURL 命令中不包含 `--data-raw` 参数

生成格式示例：
```
curl -X POST 'https://example.com/api/login' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer token123' \
  --data-raw '{"user":"foo","pass":"bar"}'
```
