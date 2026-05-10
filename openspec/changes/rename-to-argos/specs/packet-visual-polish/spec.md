## MODIFIED Requirements

### Requirement: 详情页区块卡片化
`ArgosPacketDetailPage` 中的各信息区块（基本信息、Query Params、请求头、请求体、响应信息、响应头、响应体）SHALL 各自包裹在 `Card` 中展示，Card 使用 `elevation: 0` 配合边框，区块之间有适当间距。

#### Scenario: 详情页信息区块有卡片边界
- **WHEN** 用户打开抓包记录详情页
- **THEN** 每个信息区块（如"基本信息"、"请求头"等）都有独立的卡片外框，具有圆角和细边框
