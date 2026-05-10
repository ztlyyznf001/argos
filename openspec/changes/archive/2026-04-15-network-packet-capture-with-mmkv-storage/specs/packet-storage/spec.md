## ADDED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应）序列化为 JSON 并通过 MMKV 持久化到本地。

#### Scenario: 请求完成后自动写入
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `KurilApmConfig.enableStorage` 为 `true`
- **THEN** 系统将该次请求的快照数据追加写入 MMKV，写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向 MMKV 写入任何抓包数据，已有记录不受影响

### Requirement: 最大记录条数限制
系统 SHALL 限制 MMKV 中存储的抓包记录总数，超出上限时自动淘汰最旧记录。

#### Scenario: 超出最大条数时淘汰旧记录
- **WHEN** 新记录写入后存储总条数超过 `KurilApmConfig.maxPacketRecords`（默认 200）
- **THEN** 系统删除时间最早的记录，直到总条数不超过上限

#### Scenario: 自定义最大条数
- **WHEN** 用户在 `KurilApmConfig` 中设置 `maxPacketRecords` 为自定义值（如 50）
- **THEN** 系统使用该自定义值作为上限进行淘汰

### Requirement: 读取所有抓包记录
系统 SHALL 提供接口从 MMKV 读取所有已存储的抓包记录，返回按时间倒序排列的列表。

#### Scenario: 有记录时返回列表
- **WHEN** 调用 `KurilPacketStorage.getAll()`
- **THEN** 返回当前 MMKV 中所有记录的列表，按 `startTimestamp` 倒序排列

#### Scenario: 无记录时返回空列表
- **WHEN** MMKV 中没有任何抓包记录时调用 `KurilPacketStorage.getAll()`
- **THEN** 返回空列表，不抛出异常

### Requirement: 清空所有抓包记录
系统 SHALL 提供接口一次性清空 MMKV 中存储的所有抓包记录。

#### Scenario: 清空操作
- **WHEN** 调用 `KurilPacketStorage.clear()`
- **THEN** MMKV 中的所有抓包记录被删除，随后调用 `getAll()` 返回空列表

### Requirement: 大 Body 截断
系统 SHALL 对超过 100KB 的请求体或响应体进行截断，只存储前 100KB，并在截断处附加截断标注。

#### Scenario: 响应体超过 100KB
- **WHEN** 响应体字节数超过 100 * 1024 字节
- **THEN** 只存储前 100KB 内容，并在末尾追加字符串 `"[TRUNCATED]"`

#### Scenario: 响应体未超过 100KB
- **WHEN** 响应体字节数不超过 100 * 1024 字节
- **THEN** 完整存储响应体内容，不附加任何标注
