## Context

Argos 当前的监控能力由 `ArgosCapability` 枚举驱动：`ArgosManager.init()` 读取 `ArgosConfig.apmTypes`，在 `initializeMonitors()` 中按能力项注册对应监控（`ArgosFpsMonitor`、`ArgosHttpMonitor`）。每个监控实现 `ArgosBaseMonitor`，产出 `ArgosBaseModel` 子模型，通过 `ArgosManager.instance.listener` 回调，并可选写入 `ArgosPacketStorage`（经由 `ArgosPacketRecord` 序列化快照）。

本次新增三类纯 Dart 监控（崩溃/错误、卡顿/Jank、CPU/内存），必须复用该注册机制与数据流，保持与现有 FPS/网络监控一致的接入方式，避免引入第三方依赖与原生层改动。

约束：
- 监控均为单例，惰性初始化，仅在对应 `ArgosCapability` 被配置时启用。
- 不阻塞 UI 线程；采样/回调开销可忽略。
- 复用现有存储与 Inspector UI，避免重复造轮子。

## Goals / Non-Goals

**Goals:**
- 新增 `crash`、`jank`、`resource` 三个 `ArgosCapability`，各自有独立监控实现与数据模型。
- 崩溃/错误：捕获 `FlutterError.onError` 与 Dart 未处理异常，记录类型/消息/堆栈/路由/时间戳。
- 卡顿/Jank：在 FrameTiming 基础上检测掉帧、拆分 build/raster 耗时、聚合连续卡顿区间并输出结构化事件。
- CPU/内存：周期性采样进程内存（RSS/maxRss），输出资源采样事件。
- 全部事件统一经 `ArgosManager.listener` 回调，并可选写入现有存储。
- 不引入第三方依赖、不改动 iOS/Android 原生层。

**Non-Goals:**
- 不实现原生崩溃（SIGSEGV、ANR、Java/Kotlin/Swift 层崩溃）捕获——属于原生层范畴，本次仅覆盖 Dart 侧。
- 不实现精确的进程 CPU 占用率（纯 Dart 无可靠 API，详见 Decisions）。
- 不实现远端上报/聚合后端（事件仅本地记录）。
- 不实现 widget 级 build 热点归因、内存堆快照、symbolication 反混淆。

## Decisions

### 决策 1：复用 `ArgosCapability` + `ArgosBaseMonitor` 注册机制
新增 `crash`、`jank`、`resource` 三个枚举项，在 `ArgosManager.initializeMonitors()` 的 switch 中各加一个分支注册单例监控。

- **理由**：与现有 FPS/网络监控完全一致，零学习成本，配置方式统一（`apmTypes: [...]`）。
- **替代方案**：独立的注册表/插件系统——对当前规模过度设计，放弃。

### 决策 2：崩溃/错误捕获采用双通道
- `FlutterError.onError`：捕获 Flutter 框架同步错误（build/layout/paint 期间）。
- `PlatformDispatcher.instance.onError`：捕获 Dart 未处理的异步异常（无需强制 `runZonedGuarded` 包裹 `runApp`）。
- 监控初始化时**链式保留**原有 handler（先缓存旧 `onError`，捕获记录后再调用旧 handler），避免吞掉宿主应用既有的错误上报。

- **理由**：`PlatformDispatcher.onError`（Flutter 3.3+）可在不要求宿主用 `runZonedGuarded` 包裹入口的前提下捕获异步错误，接入侵入性最低。
- **替代方案**：强制要求宿主用 `runZonedGuarded(() => runApp(...), onError)`——侵入性高且容易与宿主既有 Zone 冲突，放弃为主路径，但在文档中作为可选补充。
- **去重**：同一错误可能同时触发两通道时，以 `(exception.toString, stack 首帧)` 作为短时间窗口去重键，避免重复记录。

### 决策 3：卡顿检测基于帧预算阈值
复用 `SchedulerBinding.addTimingsCallback`。对每个 `FrameTiming`：
- 帧预算 = `1s / 显示刷新率`（默认 60Hz，优先读取 `display.refreshRate`，不可得时回退 60Hz）。
- `totalSpan > 帧预算` 判定为掉帧；记录该帧的 `buildDuration`、`rasterDuration` 以定位瓶颈在 UI 线程还是 Raster 线程。
- 连续掉帧帧聚合为一个"卡顿区间"事件（区间内总耗时、丢帧数、最大单帧耗时）。

- **理由**：FrameTiming 已暴露 build/raster 拆分，零额外采集成本即可定位卡顿来源。
- **阈值可配置**：默认掉帧阈值为 1×帧预算，预留配置项（如严重卡顿 = 3×帧预算）。
- **替代方案**：基于 `WidgetsBinding` 的逐帧时间戳手动测量——精度低于 FrameTiming，放弃。

### 决策 4：资源监控以内存为主，CPU 为近似
- 内存：周期性（默认每 2s，可配）通过 `dart:io` `ProcessInfo.currentRss` / `maxRss` 采样常驻内存。
- CPU：纯 Dart 无跨平台进程 CPU 占用 API。本次**不**承诺精确 CPU 占用率；以可得指标（如 Isolate 数、采样间隔内事件循环延迟近似）作为辅助信号，或在 design 标注为"延后/原生扩展"。资源模型字段对 CPU 留空时不输出虚假数据。
- 采样使用 `Timer.periodic`，监控 disable 时取消，避免泄漏。

- **理由**：内存是纯 Dart 可可靠获取的最有价值指标；不输出无法保证准确性的 CPU 数据，避免误导。
- **替代方案**：经原生 MethodChannel 取系统 CPU——超出"纯 Dart/本次范围"，记录为 Open Question 留待后续。

### 决策 5：复用存储与 Inspector UI
- 新模型继承 `ArgosBaseModel`，提供 `getValue()` 文本摘要与可选 `ArgosPacketRecord` 序列化，使其可经现有 `ArgosPacketStorage` 落盘。
- Inspector 优先复用现有列表/详情页展示新事件（按 `ArgosCapability.type` 区分图标/标签）；若现有 UI 强耦合 HTTP 字段，则为新事件提供轻量列表项渲染分支。具体渲染细节在实现时按现有 UI 结构裁剪。

- **理由**：最大化复用，保持 Inspector 单一入口。

## Risks / Trade-offs

- **[错误 handler 链被宿主覆盖]** 若宿主在 Argos 初始化后又重设 `FlutterError.onError`，会覆盖 Argos 的捕获 → 文档要求 Argos 初始化应在宿主自定义 handler 之后；并在监控内保留对旧 handler 的调用以减少冲突。
- **[卡顿事件过多导致噪声/存储膨胀]** 低端机持续掉帧会产生大量事件 → 采用区间聚合 + 复用 `maxPacketRecords` 上限的环形截断；预留最小卡顿时长阈值过滤。
- **[内存采样周期开销]** 过短周期增加开销 → 默认 2s 且可配；监控 disable 时取消 Timer。
- **[CPU 数据缺失招致预期落差]** 用户可能期待真实 CPU 占用 → 在 proposal/design 明确范围，模型不输出无法保证的 CPU 数值，文档说明纯 Dart 限制。
- **[错误去重误杀]** 去重窗口可能合并两个不同的真实错误 → 去重键包含堆栈首帧并限定极短时间窗口（如 500ms），降低误合并概率。

## Migration Plan

- 纯增量变更：新增枚举项与监控，不改动现有 FPS/网络行为，无破坏性变更。
- 默认不启用：仅当宿主在 `apmTypes` 中显式加入 `crash`/`jank`/`resource` 才生效，老用户升级零影响。
- 回滚：移除对应枚举项配置即可关闭新监控；代码层面新增文件互不耦合，可独立回退。

## Open Questions

- CPU 精确占用是否在后续以原生 MethodChannel 扩展实现？（本次不做）
- 新事件在 Inspector 中是复用现有列表页还是新增独立标签页？（实现时依现有 UI 结构裁剪）
- 卡顿/资源事件是否默认写入存储，还是仅回调、由宿主决定？（倾向：受 `enableStorage` 统一控制）
