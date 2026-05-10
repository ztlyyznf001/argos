## MODIFIED Requirements

### Requirement: 请求体完整捕获（含 write 系列方法）
系统 SHALL 通过 `ArgosHttpClientRequest` 捕获所有通过 `add()`、`write()`、`writeln()`、`writeAll()`、`writeCharCode()` 写入的请求体内容，保证 `ArgosPacketRecord.requestBody` 与实际发送内容一致。

#### Scenario: 通过 write() 写入的请求体被捕获
- **WHEN** 调用方通过 `request.write(body)` 发送请求体（如 JSON 字符串）
- **THEN** `ArgosPacketRecord.requestBody` 包含该字符串内容，不为空字符串

#### Scenario: 通过 add() 写入的请求体被捕获
- **WHEN** 调用方通过 `request.add(bytes)` 发送请求体
- **THEN** `ArgosPacketRecord.requestBody` 包含解码后的字符串内容

#### Scenario: 混合使用 write() 和 add() 时内容完整
- **WHEN** 调用方先后通过 `write()` 和 `add()` 写入请求体片段
- **THEN** `ArgosPacketRecord.requestBody` 为两段内容的拼接，顺序与写入顺序一致

#### Scenario: 通过 writeln() 写入时换行符被保留
- **WHEN** 调用方通过 `request.writeln(text)` 写入内容
- **THEN** `ArgosPacketRecord.requestBody` 包含 `text\n`

#### Scenario: 通过 writeAll() 写入时分隔符被保留
- **WHEN** 调用方通过 `request.writeAll(items, separator)` 写入内容
- **THEN** `ArgosPacketRecord.requestBody` 包含以 `separator` 连接的 `items` 字符串

#### Scenario: 通过 writeCharCode() 写入的字符被捕获
- **WHEN** 调用方通过 `request.writeCharCode(charCode)` 写入单个字符
- **THEN** `ArgosPacketRecord.requestBody` 包含对应 Unicode 字符
