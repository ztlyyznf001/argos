## Why

Argos 目前仅覆盖网络抓包与基础 FPS 采样两类 APM 能力，缺少应用稳定性与运行时性能的关键观测维度。线上排查崩溃、卡顿、内存问题时无法在同一工具链内获取数据，开发者需要额外接入多个 SDK。本次在 Flutter（纯 Dart）侧补齐崩溃/错误捕获、卡顿/Jank 分析、CPU/内存监控三类监控，使 Argos 成为更完整的一体化 APM 工具。

## What Changes

- 新增 **崩溃/错误捕获** 监控：通过 `FlutterError.onError` 与 `runZonedGuarded`/`PlatformDispatcher.onError` 捕获 Flutter 框架错误与 Dart 未处理异常，记录错误信息、堆栈、所属路由与时间戳，接入现有存储与 Inspector UI。
- 新增 **卡顿/Jank 分析** 监控：在现有 `FrameTiming` 采集基础上扩展，识别掉帧（超过帧预算的帧）、拆分 build 与 raster 耗时、聚合连续卡顿区间，输出卡顿事件而非仅 FPS 数值。
- 新增 **CPU/内存监控** 监控：周期性采样进程内存占用（RSS / maxRss，经由 `dart:io` `ProcessInfo`）与可获取的运行时资源指标，输出资源采样事件。纯 Dart 侧 CPU 精确占用受限，本次以内存为主、CPU 以可得近似指标为辅（详见 design）。
- 扩展 `ArgosCapability` 枚举，新增 `crash`、`jank`、`resource` 三个能力项，复用 `ArgosBaseMonitor` 基类与 `ArgosManager.initializeMonitors()` 的注册机制。
- 新增对应的 `ArgosBaseModel` 子模型（错误模型、卡顿模型、资源模型），统一经由 `ArgosManager.listener` 回调并可选写入存储。

## Capabilities

### New Capabilities
- `crash-error-capture`: 捕获 Flutter 框架错误与 Dart 未处理异常，记录错误类型、消息、堆栈、路由上下文与时间戳，统一进入 APM 数据流。
- `jank-analysis`: 基于 FrameTiming 检测掉帧与卡顿区间，拆分 build/raster 耗时并输出结构化卡顿事件。
- `resource-monitor`: 周期性采样进程内存占用等运行时资源指标并输出采样事件。

### Modified Capabilities
<!-- 现有 openspec/specs/ 中无独立 FPS 能力规格；本次新增能力均为全新 spec，不修改既有 spec 的需求。 -->

## Impact

- **新增能力开关**：`ArgosCapability` 枚举（`lib/config/argos_config.dart`）新增 `crash`、`jank`、`resource`。
- **新增监控实现**：`lib/apm/` 下新增 `argos_crash_monitor.dart`、`argos_jank_monitor.dart`、`argos_resource_monitor.dart`，均实现/扩展 `ArgosBaseMonitor`。
- **新增数据模型**：`lib/model/` 下新增对应模型，继承 `ArgosBaseModel`，提供可序列化为 `ArgosPacketRecord` 的快照能力以复用存储。
- **注册逻辑**：`ArgosManager.initializeMonitors()`（`lib/argos_manager.dart`）扩展 switch 分支注册新监控。
- **UI**：Inspector 复用现有列表/详情页展示新事件（错误、卡顿、资源），或新增对应入口（具体在 design 决定）。
- **导出**：`lib/argos.dart` 导出新增公共类型。
- **依赖**：以 Flutter/Dart 内置 API 为主（`dart:ui`、`scheduler`、`dart:io`、`dart:async`），不引入新的第三方依赖。
- **平台**：纯 Dart 实现，iOS/Android 原生层无需改动。
