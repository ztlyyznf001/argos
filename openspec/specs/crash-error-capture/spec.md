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
系统 SHALL 将每条错误记录封装为继承 `ArgosBaseModel` 的错误模型，`type` 为 `ArgosCapability.crash`，并通过 `ArgosManager.instance.listener` 回调；当 `enableStorage` 为 `true` 时序列化为 `ArgosPacketRecord` 写入 `ArgosPacketStorage`。

#### Scenario: 错误触发 listener 回调
- **WHEN** 捕获到一条框架或 Dart 异常，且 `ArgosManager.instance.listener` 不为 null
- **THEN** listener 被调用，参数为携带错误信息、`type == ArgosCapability.crash` 的错误模型

#### Scenario: 启用存储时错误落盘
- **WHEN** 捕获到一条异常且 `enableStorage` 为 `true`
- **THEN** 该错误以可序列化记录形式写入 `ArgosPacketStorage`，可在 Inspector 中查看

### Requirement: 重复错误去重
系统 SHALL 对短时间窗口内由不同通道（`FlutterError.onError` 与 `PlatformDispatcher.onError`）重复触发的同一异常去重，避免同一错误被记录两次。

#### Scenario: 同一异常只记录一次
- **WHEN** 同一个异常在极短时间窗口内同时触发了两条捕获通道，去重键（异常字符串 + 堆栈首帧）相同
- **THEN** 系统只记录并回调一次该错误
