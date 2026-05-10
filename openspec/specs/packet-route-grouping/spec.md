## ADDED Requirements

### Requirement: 路由分组展开列表
`ArgosPacketListPage` SHALL 将抓包记录按 `routeName` 分组，以可展开/折叠的 `ExpansionTile` 列表形式展示。每个分组标题显示路由名称和该分组的记录条数，默认全部展开。空字符串 `routeName` 归入"未知页面"分组。

#### Scenario: 有多个路由记录时展示分组
- **WHEN** 存储中存在来自两个或以上不同 `routeName` 的记录
- **THEN** 列表按 routeName 分组，每组为一个 ExpansionTile，标题展示路由名称和记录条数，默认展开

#### Scenario: 所有记录 routeName 相同时只有一个分组
- **WHEN** 所有记录的 `routeName` 相同
- **THEN** 列表只有一个分组，行为与单分组 ExpansionTile 一致

#### Scenario: 无记录时不展示任何分组
- **WHEN** 存储中没有任何抓包记录（或当前过滤条件下无匹配记录）
- **THEN** 不展示任何 ExpansionTile，展示空状态提示

### Requirement: 分组与搜索、Method 过滤联动
搜索栏或 Method 过滤条件变更时，SHALL 重新计算各分组内容；过滤后某分组内记录为空时，该分组 SHALL 被隐藏。

#### Scenario: 搜索后空分组隐藏
- **WHEN** 用户在搜索栏输入关键词，某个路由下所有记录均不匹配
- **THEN** 该路由分组从列表中隐藏，其他有匹配记录的分组正常展示

#### Scenario: Method 过滤与分组叠加
- **WHEN** 用户选中某个 Method（如 POST）
- **THEN** 每个分组内只展示该 Method 的记录，无匹配记录的分组被隐藏

### Requirement: 空 routeName 归入"未知页面"分组
`routeName` 为空字符串的记录 SHALL 统一归入标题为"未知页面"的分组，不展示空字符串作为分组标题。

#### Scenario: 空 routeName 记录归入"未知页面"
- **WHEN** 存储中存在 `routeName` 为空字符串的记录
- **THEN** 这些记录归入标题为"未知页面"的 ExpansionTile 分组

#### Scenario: 无空 routeName 记录时不出现"未知页面"分组
- **WHEN** 所有记录的 `routeName` 均非空
- **THEN** 列表中不出现"未知页面"分组
