## MODIFIED Requirements

### Requirement: 数据入口支持原生双通道
系统 SHALL 支持「Dart HttpOverrides」和「原生 EventChannel」两条独立数据入口，两者均通过 `ArgosPacketStorage.append()` 写入同一存储，在 UI 层展示为统一列表。

#### Scenario: Dart 层请求写入存储
- **WHEN** Dart 层 HTTP 请求经 `ArgosHttpMonitor` 捕获
- **THEN** 该记录通过 `ArgosPacketStorage.append()` 写入，UI 中可见

#### Scenario: 原生层请求写入存储
- **WHEN** 原生层请求经 EventChannel 推送到 Dart，`ArgosNativeCapture` 解析后调用 `ArgosPacketStorage.append()`
- **THEN** 该记录写入同一存储，与 Dart 层记录共同出现在 UI 列表中，按 `startTimestamp` 降序排列

#### Scenario: 两路请求同时发生时不丢失
- **WHEN** Dart 层和原生层同时发出 HTTP 请求
- **THEN** 两条记录均出现在存储中，`_writeChain` 串行化保证无并发写冲突
