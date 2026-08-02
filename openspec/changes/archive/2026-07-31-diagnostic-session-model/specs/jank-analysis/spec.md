## MODIFIED Requirements

### Requirement: 卡顿事件进入统一数据流
系统 SHALL 将聚合后的卡顿事件封装为 type 为 `ArgosCapability.jank` 的模型与可序列化记录，并交给 `ArgosManager.dispatch`。只有 sessionState 为 recording 时卡顿事件才进入 listener 和可选存储；被接受的记录 SHALL 带有 activeSession.id 与 sequence。

#### Scenario: recording 时卡顿进入会话
- **WHEN** recording 会话中生成一个卡顿区间且 listener 不为 null
- **THEN** listener 收到一次 jank 模型回调，对应记录带有 activeSession.id 和下一 sequence

#### Scenario: 启用存储时卡顿落盘
- **WHEN** recording 会话中生成卡顿区间且 enableStorage 为 true
- **THEN** 卡顿记录经统一 dispatch 写入所属会话，可按 sessionId 查询

#### Scenario: paused 时卡顿不产生记录
- **WHEN** sessionState 为 paused 或 idle 时帧回调检测到卡顿
- **THEN** Argos 不调用 listener、不写入卡顿记录且不消耗 sequence；已有帧订阅可保持安装
