## ADDED Requirements

### Requirement: 错误请求也持久化存储
系统 SHALL 在 HTTP 请求失败时（`KurilHttpInfo.error != null`）将错误快照持久化到 MMKV，与正常请求记录共享同一存储和上限机制。

#### Scenario: 错误记录写入 MMKV
- **WHEN** 一次 HTTP 请求因网络异常失败，且 `enableStorage` 为 `true`，且 host 在白名单中
- **THEN** MMKV 中增加一条记录，其中 `responseCode = 0`，`responseBody = ''`，`error` 字段包含错误描述

#### Scenario: 错误记录参与最大条数淘汰
- **WHEN** 错误记录写入后总条数超过 `maxPacketRecords`
- **THEN** 最旧的记录（无论是正常还是错误）被淘汰，直到总条数不超过上限
