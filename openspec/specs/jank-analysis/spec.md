# jank-analysis Specification

## Purpose
定义 Argos 卡顿分析能力：在启用 `ArgosCapability.jank` 时订阅帧耗时，基于帧预算检测掉帧、拆分 build/raster 耗时、聚合连续掉帧为卡顿区间，并将卡顿事件送入统一数据流。

## Requirements

### Requirement: 启用 jank 能力时注册卡顿监控
系统 SHALL 在 `ArgosConfig.apmTypes` 包含 `ArgosCapability.jank` 时，于 `ArgosManager.initializeMonitors()` 注册卡顿监控并通过 `SchedulerBinding.instance.addTimingsCallback` 订阅帧耗时。

#### Scenario: 配置 jank 能力后监控生效
- **WHEN** 宿主以 `ArgosConfig(apmTypes: [ArgosCapability.jank])` 调用 `ArgosManager.init()`
- **THEN** 卡顿监控被初始化，并注册了 `addTimingsCallback` 回调以接收 `FrameTiming`

#### Scenario: 未配置 jank 能力时不订阅帧耗时
- **WHEN** 宿主的 `apmTypes` 不包含 `ArgosCapability.jank`
- **THEN** 卡顿监控不注册帧耗时回调

### Requirement: 基于帧预算检测掉帧
系统 SHALL 以当前显示刷新率推导帧预算（`1s / refreshRate`，不可得时回退 60Hz），将 `FrameTiming.totalSpan` 超过帧预算的帧判定为掉帧。

#### Scenario: 超预算帧被判定为掉帧
- **WHEN** 某一帧的 `totalSpan` 大于帧预算（如 60Hz 下大于约 16.67ms）
- **THEN** 系统将该帧标记为掉帧并纳入卡顿统计

#### Scenario: 正常帧不计入卡顿
- **WHEN** 某一帧的 `totalSpan` 不超过帧预算
- **THEN** 系统不将该帧标记为掉帧

### Requirement: 拆分 build 与 raster 耗时
系统 SHALL 为掉帧记录其 `buildDuration` 与 `rasterDuration`，用于定位卡顿瓶颈位于 UI 线程还是 Raster 线程。

#### Scenario: 卡顿事件包含线程耗时拆分
- **WHEN** 系统生成一个卡顿事件
- **THEN** 该事件包含对应帧的 `buildDuration`（UI 线程）与 `rasterDuration`（Raster 线程）数据

### Requirement: 聚合连续掉帧为卡顿区间
系统 SHALL 将连续的掉帧聚合为一个卡顿区间事件，记录区间内的丢帧数量、总耗时与最大单帧耗时，避免逐帧产生过多事件。

#### Scenario: 连续掉帧聚合为单个事件
- **WHEN** 出现连续多帧掉帧
- **THEN** 系统输出一个卡顿区间事件，包含丢帧数、区间总耗时与最大单帧耗时，而非每帧一个事件

### Requirement: 卡顿事件进入统一数据流
系统 SHALL 将卡顿事件封装为继承 `ArgosBaseModel` 的卡顿模型，`type` 为 `ArgosCapability.jank`，并通过 `ArgosManager.instance.listener` 回调；当 `enableStorage` 为 `true` 时序列化写入 `ArgosPacketStorage`。

#### Scenario: 卡顿触发 listener 回调
- **WHEN** 系统生成一个卡顿事件，且 `ArgosManager.instance.listener` 不为 null
- **THEN** listener 被调用，参数为携带卡顿信息、`type == ArgosCapability.jank` 的卡顿模型

#### Scenario: 启用存储时卡顿落盘
- **WHEN** 系统生成一个卡顿事件且 `enableStorage` 为 `true`
- **THEN** 该卡顿事件以可序列化记录形式写入 `ArgosPacketStorage`
