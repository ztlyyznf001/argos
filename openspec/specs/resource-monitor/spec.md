# resource-monitor Specification

## Purpose
定义 Argos 资源监控能力：在启用 `ArgosCapability.resource` 时按周期采样进程内存（RSS），在 CPU 数据不可靠时留空而非伪造，将资源事件送入统一数据流，并在停用时释放定时器。

## Requirements

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
系统 SHALL 将资源采样封装为 type 为 `ArgosCapability.resource` 的模型与可序列化记录，并交给 `ArgosManager.dispatch`。只有 sessionState 为 recording 时资源事件才进入 listener 和可选存储；被接受的记录 SHALL 带有 activeSession.id 与 sequence。暂停期间周期定时器 MAY 保持安装，但 MUST NOT 生成可见或持久化记录。

#### Scenario: recording 时资源采样进入会话
- **WHEN** recording 会话中到达资源采样周期且 listener 不为 null
- **THEN** listener 收到 resource 模型回调，对应记录带有 activeSession.id 和下一 sequence

#### Scenario: 启用存储时资源采样落盘
- **WHEN** recording 会话中生成资源采样且 enableStorage 为 true
- **THEN** 资源记录经统一 dispatch 写入所属会话，可按 sessionId 查询

#### Scenario: paused 时资源采样不产生记录
- **WHEN** sessionState 为 paused 或 idle 时资源采样定时器触发
- **THEN** Argos 不调用 listener、不写入资源记录且不消耗 sequence

### Requirement: 监控停止时释放采样定时器
系统 SHALL 在资源监控被停用或销毁时取消周期性采样定时器，避免资源泄漏与后台无效采样。

#### Scenario: 停用监控后停止采样
- **WHEN** 资源监控被停用
- **THEN** 采样定时器被取消，不再产生新的资源采样事件
