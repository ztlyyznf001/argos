## MODIFIED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应，含路由名称）序列化为 JSON 并通过注入的 `ArgosStorageAdapter` 持久化。存储后端由宿主注入，`ArgosPacketStorage` 不依赖任何具体存储引擎。

#### Scenario: 请求完成后自动写入（含路由名称）
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `ArgosConfig.enableStorage` 为 `true` 且 `storageAdapter` 已注入
- **THEN** 系统将该次请求的快照数据（含 `routeName` 字段）追加写入 adapter，写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向 adapter 写入任何抓包数据，已有记录不受影响

### Requirement: 最大记录条数限制
系统 SHALL 限制 adapter 中存储的抓包记录总数，超出上限时自动淘汰最旧记录。条数限制逻辑由 `ArgosPacketStorage` 在读取 adapter 数据后进行，与存储后端实现无关。

#### Scenario: 超出最大条数时淘汰旧记录
- **WHEN** 新记录写入后存储总条数超过 `ArgosConfig.maxPacketRecords`（默认 200）
- **THEN** 系统删除时间最早的记录，直到总条数不超过上限

#### Scenario: 自定义最大条数
- **WHEN** 用户在 `ArgosConfig` 中设置 `maxPacketRecords` 为自定义值（如 50）
- **THEN** 系统使用该自定义值作为上限进行淘汰

### Requirement: 读取所有抓包记录
系统 SHALL 提供接口从 `ArgosStorageAdapter` 读取所有已存储的抓包记录，返回按时间倒序排列的列表。

#### Scenario: 有记录时返回列表
- **WHEN** 调用 `ArgosPacketStorage.getAllAsync()`
- **THEN** 返回当前 adapter 中所有记录的列表，按 `startTimestamp` 倒序排列

#### Scenario: 无记录时返回空列表
- **WHEN** adapter 中没有任何抓包记录时调用 `ArgosPacketStorage.getAllAsync()`
- **THEN** 返回空列表，不抛出异常

### Requirement: 清空所有抓包记录
系统 SHALL 提供接口一次性清空 `ArgosStorageAdapter` 中存储的所有抓包记录。

#### Scenario: 清空操作
- **WHEN** 调用 `ArgosPacketStorage.clear()`
- **THEN** adapter 中的所有抓包记录被删除，随后调用 `getAllAsync()` 返回空列表

## REMOVED Requirements

### Requirement: 抓包数据持久化存储（MMKV 实现）
**Reason**: 存储后端抽象化后，MMKV 不再是包内硬依赖，由宿主自行选择实现
**Migration**: 宿主创建继承 `ArgosStorageAdapter` 的 MMKV 实现类，在 `ArgosConfig` 中注入即可还原原有行为
