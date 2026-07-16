## 1. 能力枚举与脚手架

- [x] 1.1 在 `lib/config/argos_config.dart` 的 `ArgosCapability` 枚举新增 `crash`、`jank`、`resource` 三项
- [x] 1.2 在 `ArgosConfig` 增加可选配置项（如卡顿阈值倍数、资源采样周期），保持向后兼容默认值
- [x] 1.3 在 `ArgosManager.initializeMonitors()` 的 switch 中新增 `crash`、`jank`、`resource` 三个注册分支（先占位调用，后续填充实现）

## 2. 数据模型

- [x] 2.1 新增 `lib/model/argos_crash_info_model.dart`：继承 `ArgosBaseModel`，字段含异常消息、堆栈、路由、时间戳，`type = ArgosCapability.crash`，实现 `getValue()`
- [x] 2.2 新增 `lib/model/argos_jank_info_model.dart`：继承 `ArgosBaseModel`，字段含丢帧数、区间总耗时、最大单帧耗时、buildDuration、rasterDuration，`type = ArgosCapability.jank`，实现 `getValue()`
- [x] 2.3 新增 `lib/model/argos_resource_info_model.dart`：继承 `ArgosBaseModel`，字段含 currentRss、maxRss、可空 cpu、时间戳，`type = ArgosCapability.resource`，实现 `getValue()`
- [x] 2.4 为三个模型提供可选的 `ArgosPacketRecord` 序列化快照，使其可经 `ArgosPacketStorage` 落盘

## 3. 崩溃/错误捕获监控

- [x] 3.1 新增 `lib/apm/argos_crash_monitor.dart`：单例，实现 `ArgosBaseMonitor`，`init()` 缓存并链式保留原 `FlutterError.onError`
- [x] 3.2 安装 `FlutterError.onError` 捕获框架同步错误，记录消息/堆栈/`currentRoute`/时间戳，捕获后调用原 handler
- [x] 3.3 安装 `PlatformDispatcher.instance.onError` 捕获 Dart 未处理异步异常，链式保留原 handler
- [x] 3.4 实现去重逻辑（异常字符串 + 堆栈首帧 + 短时间窗口）避免双通道重复记录
- [x] 3.5 统一出口：生成错误模型 → 触发 `ArgosManager.instance.listener` → `enableStorage` 为 true 时写入 `ArgosPacketStorage`

## 4. 卡顿/Jank 分析监控

- [x] 4.1 新增 `lib/apm/argos_jank_monitor.dart`：单例，实现 `ArgosBaseMonitor`，`init()` 注册 `SchedulerBinding.addTimingsCallback`
- [x] 4.2 推导帧预算（优先 `display.refreshRate`，回退 60Hz），按 `totalSpan > 帧预算` 判定掉帧
- [x] 4.3 记录掉帧的 `buildDuration` 与 `rasterDuration` 拆分
- [x] 4.4 实现连续掉帧聚合为卡顿区间（丢帧数、区间总耗时、最大单帧耗时）
- [x] 4.5 统一出口：生成卡顿模型 → 触发 listener → `enableStorage` 为 true 时写入存储

## 5. CPU/内存资源监控

- [x] 5.1 新增 `lib/apm/argos_resource_monitor.dart`：单例，实现 `ArgosBaseMonitor`，`init()` 启动 `Timer.periodic`（默认 2s，可配）
- [x] 5.2 周期采样 `ProcessInfo.currentRss` 与 `ProcessInfo.maxRss`
- [x] 5.3 CPU 不可得时字段留空，不输出估算/占位值
- [x] 5.4 提供停用/销毁入口取消 Timer，避免泄漏
- [x] 5.5 统一出口：生成资源模型 → 触发 listener → `enableStorage` 为 true 时写入存储

## 6. 注册接入与导出

- [x] 6.1 在 `ArgosManager.initializeMonitors()` 填充三个分支，注册对应监控单例并传入配置
- [x] 6.2 在 `lib/argos.dart` 导出新增模型与监控的公共类型
- [x] 6.3 校验未配置新能力时不安装任何 handler/定时器（不影响现有 FPS/网络行为）

## 7. Inspector UI 接入

- [x] 7.1 评估现有 `ArgosPacketListPage` 列表项渲染，按 `ArgosBaseModel.type` 为错误/卡顿/资源事件提供区分图标与标签
- [x] 7.2 为新事件提供详情展示（错误堆栈、卡顿拆分、资源采样曲线/数值），复用或裁剪现有详情页
- [x] 7.3 确保新事件与 HTTP 包在同一 Inspector 入口可浏览、可清除

## 8. 示例与验证

- [x] 8.1 在 `example/` 中演示启用 `crash`/`jank`/`resource` 能力，并提供触发按钮（抛异常、制造卡顿、查看内存）
- [x] 8.2 手动验证三类事件均能回调 listener 并在 Inspector 中显示
- [x] 8.3 手动验证 `enableStorage` 为 true 时三类事件正确落盘并可读取
- [x] 8.4 运行 `flutter analyze` 确保无静态分析告警
- [x] 8.5 更新 README 说明新增的三类 APM 能力与配置方式
