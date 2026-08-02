# crash-error-capture Specification

## Purpose
定义 Argos 崩溃/错误捕获能力：在启用 `ArgosCapability.crash` 时安装 Flutter 框架错误与 Dart 未处理异步异常的捕获入口，保留宿主原有 handler，并将错误事件送入统一数据流。

## Requirements

### Requirement: 启用 crash 能力时注册错误捕获
系统 SHALL 在 `ArgosConfig.apmTypes` 包含 `ArgosCapability.crash` 时，于 `ArgosManager.initializeMonitors()` 注册崩溃/错误监控并安装错误捕获 handler。

#### Scenario: 配置 crash 能力后监控生效
- **WHEN** 宿主以 `ArgosConfig(apmTypes: [ArgosCapability.crash])` 调用 `ArgosManager.init()`
- **THEN** 崩溃/错误监控被初始化，`FlutterError.onError` 与 `PlatformDispatcher.instance.onError` 被安装为捕获入口

#### Scenario: 未配置 crash 能力时不安装 handler
- **WHEN** 宿主的 `apmTypes` 不包含 `ArgosCapability.crash`
- **THEN** 系统不修改 `FlutterError.onError` 与 `PlatformDispatcher.onError`，宿主原有错误处理不受影响

### Requirement: 捕获 Flutter 框架错误
系统 SHALL 通过 `FlutterError.onError` 捕获 Flutter 框架在 build/layout/paint 等阶段抛出的同步错误，并记录错误消息、堆栈与上下文。

#### Scenario: widget build 抛错被捕获
- **WHEN** 某个 widget 在 build 过程中抛出异常，触发 `FlutterError.onError`
- **THEN** 系统生成一条错误记录，包含异常消息（`exceptionAsString`）、堆栈（`FlutterErrorDetails.stack`）、当前路由（`ArgosManager.instance.currentRoute`）与时间戳

### Requirement: 捕获 Dart 未处理异步异常
系统 SHALL 通过 `PlatformDispatcher.instance.onError` 捕获未被 try/catch 处理的 Dart 异步异常，且不要求宿主以 `runZonedGuarded` 包裹入口。

#### Scenario: 未捕获的异步异常被记录
- **WHEN** 应用中一个未被处理的 `Future` 抛出异常，触发 `PlatformDispatcher.onError`
- **THEN** 系统生成一条错误记录，包含异常对象的字符串表示、堆栈与时间戳

### Requirement: 保留并链式调用宿主原有 handler
系统 SHALL 在安装自身错误 handler 前缓存宿主已有的 `FlutterError.onError` 与 `PlatformDispatcher.onError`，并在记录错误后调用被缓存的原 handler，避免吞掉宿主既有的错误上报。

#### Scenario: 原有 FlutterError handler 仍被调用
- **WHEN** 宿主在调用 `ArgosManager.init()` 前已设置自定义 `FlutterError.onError`，随后发生框架错误
- **THEN** 系统先记录该错误，再调用宿主先前设置的 `FlutterError.onError`，宿主回调正常收到该错误

### Requirement: 错误事件进入统一数据流
系统 SHALL 将每条错误封装为 type 为 `ArgosCapability.crash` 的模型与可序列化记录，并交给 `ArgosManager.dispatch`。只有 sessionState 为 recording 时错误才进入 listener 和可选存储；写入存储的错误 SHALL 带有 activeSession.id 和 sequence。enableStorage 为 true 时，错误记录追加完成后系统 SHALL 发起 best-effort `flush()`，且 flush 失败 MUST NOT 阻止宿主原错误 handler 继续执行。

#### Scenario: recording 时错误触发 listener
- **WHEN** recording 会话中捕获到异常且 listener 不为 null
- **THEN** listener 被调用一次，参数为 type 等于 crash 的错误模型，对应记录已分配 activeSession.id 和 sequence

#### Scenario: paused 时错误不进入 Argos 数据流
- **WHEN** 捕获到异常时 sessionState 为 paused 或 idle
- **THEN** Argos 不调用 listener、不写入存储且不消耗 sequence，但仍链式调用宿主原错误 handler

#### Scenario: 启用存储时错误落盘并刷新
- **WHEN** recording 会话中捕获到异常、enableStorage 为 true 且 storageAdapter 可用
- **THEN** 错误记录先经串行队列追加到所属会话，随后系统发起一次 best-effort flush 以缩短进程退出丢失窗口

#### Scenario: crash flush 失败不吞宿主处理
- **WHEN** 错误记录后的 adapter flush 抛出异常
- **THEN** Argos 捕获并报告存储失败，宿主先前安装的 FlutterError 或 PlatformDispatcher handler 仍被调用

### Requirement: 重复错误去重
系统 SHALL 对短时间窗口内由不同通道（`FlutterError.onError` 与 `PlatformDispatcher.onError`）重复触发的同一异常去重，避免同一错误被记录两次。

#### Scenario: 同一异常只记录一次
- **WHEN** 同一个异常在极短时间窗口内同时触发了两条捕获通道，去重键（异常字符串 + 堆栈首帧）相同
- **THEN** 系统只记录并回调一次该错误
