## ADDED Requirements

### Requirement: 会话边界终止资源聚合
资源采样聚合 SHALL 以 sessionId 为硬边界。即使两个资源样本在全局排序中相邻，只要 sessionId 不同或其中一个 sessionId 为空，系统 MUST NOT 将它们折叠为同一个聚合项。

#### Scenario: 相邻样本属于不同会话
- **WHEN** 两条按时间相邻的 resource 记录分别属于两个不同的非空 sessionId
- **THEN** 列表聚合逻辑生成两个独立聚合项，不跨会话计算区间、峰值或样本数量

#### Scenario: 历史记录与会话记录相邻
- **WHEN** sessionId 为空的旧 resource 记录与某个新会话 resource 记录相邻
- **THEN** 两者之间形成聚合边界，不会把历史样本归入新会话
