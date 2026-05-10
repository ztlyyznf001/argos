## MODIFIED Requirements

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
