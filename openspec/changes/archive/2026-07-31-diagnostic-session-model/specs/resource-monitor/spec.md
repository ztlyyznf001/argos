## MODIFIED Requirements

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
