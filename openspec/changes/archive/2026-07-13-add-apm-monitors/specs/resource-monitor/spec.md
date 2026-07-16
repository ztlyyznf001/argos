## ADDED Requirements

### Requirement: 启用 resource 能力时注册资源监控
系统 SHALL 在 `ArgosConfig.apmTypes` 包含 `ArgosCapability.resource` 时，于 `ArgosManager.initializeMonitors()` 注册资源监控并启动周期性采样。

#### Scenario: 配置 resource 能力后监控生效
- **WHEN** 宿主以 `ArgosConfig(apmTypes: [ArgosCapability.resource])` 调用 `ArgosManager.init()`
- **THEN** 资源监控被初始化并启动周期性采样定时器

#### Scenario: 未配置 resource 能力时不采样
- **WHEN** 宿主的 `apmTypes` 不包含 `ArgosCapability.resource`
- **THEN** 资源监控不启动采样定时器

### Requirement: 周期性采样进程内存
系统 SHALL 按可配置周期（默认 2 秒）通过 `dart:io` 的 `ProcessInfo.currentRss` 与 `ProcessInfo.maxRss` 采样进程常驻内存占用。

#### Scenario: 按周期产出内存采样
- **WHEN** 资源监控运行且到达采样周期
- **THEN** 系统读取 `ProcessInfo.currentRss` 与 `maxRss`，生成一条包含当前 RSS、峰值 RSS 与时间戳的资源采样事件

#### Scenario: 采样周期可配置
- **WHEN** 宿主通过配置指定了非默认采样周期
- **THEN** 系统按指定周期进行采样

### Requirement: CPU 数据按可得性输出
系统 SHALL 在纯 Dart 无法可靠获取进程 CPU 占用率时，不在资源事件中输出虚假或不可保证准确性的 CPU 数值；CPU 字段在不可得时保持为空。

#### Scenario: CPU 不可得时字段留空
- **WHEN** 运行环境无法提供可靠的进程 CPU 占用率
- **THEN** 资源采样事件的 CPU 相关字段为空，而非填充估算或占位数值

### Requirement: 资源事件进入统一数据流
系统 SHALL 将资源采样事件封装为继承 `ArgosBaseModel` 的资源模型，`type` 为 `ArgosCapability.resource`，并通过 `ArgosManager.instance.listener` 回调；当 `enableStorage` 为 `true` 时序列化写入 `ArgosPacketStorage`。

#### Scenario: 资源采样触发 listener 回调
- **WHEN** 系统产出一条资源采样事件，且 `ArgosManager.instance.listener` 不为 null
- **THEN** listener 被调用，参数为携带内存采样信息、`type == ArgosCapability.resource` 的资源模型

#### Scenario: 启用存储时资源采样落盘
- **WHEN** 系统产出一条资源采样事件且 `enableStorage` 为 `true`
- **THEN** 该事件以可序列化记录形式写入 `ArgosPacketStorage`

### Requirement: 监控停止时释放采样定时器
系统 SHALL 在资源监控被停用或销毁时取消周期性采样定时器，避免资源泄漏与后台无效采样。

#### Scenario: 停用监控后停止采样
- **WHEN** 资源监控被停用
- **THEN** 采样定时器被取消，不再产生新的资源采样事件
