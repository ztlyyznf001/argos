## MODIFIED Requirements

### Requirement: 最大记录条数限制
系统 SHALL 按 `ArgosPacketRecord.kind` 分区限制存储的记录条数：每个类型各自持有独立的保留上限，某类型写入超限时，仅淘汰**该类型**时间最早的记录，MUST NOT 因某一类型的写入而淘汰其他类型的记录。配额解析规则为：`kind == 'resource'` 使用 `ArgosConfig.resourceMaxRecords`（默认 50），其余所有类型使用 `ArgosConfig.maxPacketRecords`（默认 200）。

#### Scenario: 某类型超限时只淘汰该类型最旧记录
- **WHEN** 某一类型（如 `resource`）新记录写入后，该类型的记录条数超过其配额
- **THEN** 系统删除**该类型**中时间最早的记录，直到该类型条数不超过其配额，其他类型的记录不受影响

#### Scenario: 资源采样不淘汰崩溃与网络记录
- **WHEN** 存储中已有崩溃与网络记录，随后持续写入大量资源采样记录直至资源类型触及其上限
- **THEN** 先前的崩溃与网络记录仍然保留，不因资源采样的写入而被淘汰

#### Scenario: 各类型独立触顶互不影响
- **WHEN** 网络记录已达 `maxPacketRecords`，此时写入一条崩溃记录
- **THEN** 该崩溃记录正常写入，不会因为网络记录已满而被拒绝或触发网络记录之外的淘汰；崩溃类型按其自身配额独立淘汰

#### Scenario: 自定义资源配额
- **WHEN** 用户在 `ArgosConfig` 中设置 `resourceMaxRecords` 为自定义值（如 20）
- **THEN** 系统以该值作为资源类型的保留上限进行淘汰

#### Scenario: 自定义非资源配额
- **WHEN** 用户在 `ArgosConfig` 中设置 `maxPacketRecords` 为自定义值（如 50）
- **THEN** 系统以该值作为每个非资源类型（网络/崩溃/卡顿）各自的保留上限

#### Scenario: 向后兼容默认值
- **WHEN** 用户未设置 `resourceMaxRecords`
- **THEN** 资源类型使用默认上限 50，非资源类型使用 `maxPacketRecords`（默认 200），启用存储的既有行为对只抓网络的场景保持不变

### Requirement: 错误请求也持久化存储
系统 SHALL 在 HTTP 请求失败时（`ArgosHttpInfo.error != null`）将错误快照持久化到 MMKV，与正常请求记录共享同一存储和淘汰机制。错误记录属于 `network` 类型，参与 `network` 类型的配额淘汰。

#### Scenario: 错误记录写入 MMKV
- **WHEN** 一次 HTTP 请求因网络异常失败，且 `enableStorage` 为 `true`，且 host 在白名单中
- **THEN** MMKV 中增加一条记录，其中 `responseCode = 0`，`responseBody = ''`，`error` 字段包含错误描述

#### Scenario: 错误记录参与 network 类型的配额淘汰
- **WHEN** 错误记录写入后，`network` 类型的记录条数超过 `maxPacketRecords`
- **THEN** 系统淘汰 `network` 类型中时间最早的记录（无论正常还是错误），直到该类型条数不超过上限；其他类型的记录不受影响
