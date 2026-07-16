## Why

所有记录——网络、崩溃、卡顿、资源——都经 `ArgosManager.dispatch()` 写入 `ArgosPacketStorage` 的**同一条 FIFO 列表**，共享单一的 `maxPacketRecords` 上限（默认 200），淘汰时不区分类型、一律删最旧的一条（`records.removeAt(0)`）。

资源监控默认每 2 秒采样一次并逐条落盘，于是资源采样会在**不到 7 分钟内**（200 ÷ 30 条/分钟 ≈ 6.7 分钟）填满整条列表，把此前捕获的崩溃与网络请求全部挤出——而崩溃恰恰是最不该被一串例行内存采样淹没的记录。`add-apm-monitors` 引入四类事件时沿用了这套「一个共享配额」的淘汰策略，`improve-record-display-ui` 也只在展示层做了聚合、缓解了刺眼但没有触及落盘。这个问题必须在存储层解决。

## What Changes

- **按事件类型分区淘汰**：`ArgosPacketStorage` 不再对整条列表做单一 FIFO 淘汰，而是按 `ArgosPacketRecord.kind` 分组，各类型各自持有独立的保留上限；某一类型写入超限时，只淘汰**该类型**最旧的记录，绝不波及其他类型。
- **可配置的按类型配额**：在 `ArgosConfig` 新增按类型的配额配置（如 `resourceMaxRecords`），资源类默认给一个较小的上限（如 50），其余类型沿用 `maxPacketRecords`。未配置时保持向后兼容的合理默认值。
- **保证崩溃不被例行采样挤掉**：无论资源采样多频繁，一条既有的崩溃或网络记录都不会因资源写入而被淘汰。

## Capabilities

### New Capabilities
<!-- 无。本次是对既有存储淘汰行为的修改，不引入新能力。 -->

### Modified Capabilities
- `packet-storage`: 「最大记录条数限制」由「整条列表单一 FIFO 上限」改为「按 `kind` 分区、各类型独立上限」的淘汰策略；新增按类型配额的配置。

## Impact

- 影响文件：`lib/storage/argos_packet_storage.dart`（`_writeAsync` 的淘汰逻辑由全局改为按 kind 分区）、`lib/config/argos_config.dart`（新增按类型配额字段）、`lib/argos_manager.dart` 与调用 `append`/`appendRecord` 处的配额传参。
- 不改动监控采集频率（`lib/apm/argos_resource_monitor.dart` 仍每 2s 采样）、数据模型与展示层——本次仅改变**落盘保留策略**。
- 向后兼容：未配置新字段时，行为等价于「资源类有独立较小上限、其余沿用 `maxPacketRecords`」；既有 `maxPacketRecords` 语义对非资源类型保持不变。
- 写放大问题（每 2s 全量读-改-写整条列表）不在本次范围内；如需进一步降低存储 churn，可另开变更评估「降低资源落盘频率」。
