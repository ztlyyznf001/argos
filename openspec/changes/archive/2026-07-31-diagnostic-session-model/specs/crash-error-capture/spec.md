## MODIFIED Requirements

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
