## ADDED Requirements

### Requirement: 列表页路由分组展开列表
`KurilPacketListPage` SHALL 将记录以按路由分组的 `ExpansionTile` 列表形式展示（见 `packet-route-grouping` spec），替代原有的平铺列表。搜索栏和 Method 过滤器在分组视图下仍然生效。

#### Scenario: 初始化时所有分组默认展开
- **WHEN** 用户打开 `KurilPacketListPage`
- **THEN** 所有路由分组默认处于展开状态，可直接看到每组的记录列表

#### Scenario: 用户折叠/展开某个分组
- **WHEN** 用户点击某个路由分组标题
- **THEN** 该分组在展开和折叠之间切换，其他分组状态不变

#### Scenario: 记录刷新后分组重新计算
- **WHEN** 用户从详情页返回列表页（数据重新加载）
- **THEN** 分组根据最新记录的 routeName 集合重新生成，各分组展开状态重置为默认展开
