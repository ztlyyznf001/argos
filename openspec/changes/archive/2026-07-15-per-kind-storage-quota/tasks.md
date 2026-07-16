## 1. 配置

- [x] 1.1 在 `lib/config/argos_config.dart` 的 `ArgosConfig` 新增 `resourceMaxRecords`（默认 50），保持其余字段与构造函数向后兼容

## 2. 存储层分区淘汰

- [x] 2.1 在 `ArgosPacketStorage.append` 与 `appendRecord` 的签名并列新增 `resourceMaxRecords` 参数（带默认值 50）
- [x] 2.2 将 `_writeAsync` 的淘汰逻辑由「全局 `while length > maxRecords: removeAt(0)`」改为「按本次写入记录的 `kind` 解析配额，仅淘汰该 kind 时间最早的多余记录」
- [x] 2.3 配额解析：`kind == 'resource'` 用 `resourceMaxRecords`，其余用 `maxRecords`；保持存储列表插入顺序（末尾最新）
- [x] 2.4 确认 `getAllAsync` 仍按 `startTimestamp` 倒序返回，混合时间线顺序不受淘汰改动影响

## 3. 调用点接入

- [x] 3.1 `lib/argos_manager.dart` 的 `dispatch()` 在 `appendRecord` 调用中传入 `resourceMaxRecords: config?.resourceMaxRecords ?? 50`
- [x] 3.2 `lib/apm/argos_http_monitor.dart` 与 `lib/native/argos_native_capture.dart` 的写入调用同步传入资源配额参数（网络/原生均为非资源类型，行为不变，仅保证签名一致）

## 4. 验证

- [x] 4.1 单元测试：持续写入资源采样至其上限，断言先前写入的崩溃与网络记录仍在
- [x] 4.2 单元测试：某类型超限时只淘汰该类型最旧记录，其他类型条数不变
- [x] 4.3 单元测试：各类型独立触顶（网络写满后写崩溃，崩溃正常保留）
- [x] 4.4 单元测试：自定义 `resourceMaxRecords` 与 `maxPacketRecords` 均生效
- [x] 4.5 单元测试：未配置 `resourceMaxRecords` 时资源默认上限为 50
- [x] 4.6 运行 `flutter analyze` 无告警，`flutter test` 全绿（含既有测试无回归）

## 5. 文档

- [x] 5.1 更新 README/配置说明：`maxPacketRecords` 现为「每个非资源类型各自的上限」，并说明 `resourceMaxRecords` 的作用与默认值
