## MODIFIED Requirements

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
