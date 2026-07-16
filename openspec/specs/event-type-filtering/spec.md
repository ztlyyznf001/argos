# event-type-filtering Specification

## Purpose

定义 Inspector 列表页的事件类型过滤能力：在网络、崩溃、卡顿、资源四类记录构成的混合事件流上，按事件类型单选过滤并展示各类型条数；将 HTTP Method 过滤降级为网络类型下的二级过滤，避免 APM 事件被 Method 过滤误伤；并规定类型过滤与 URL 搜索、路由分组之间的联动关系。

## Requirements

### Requirement: 按事件类型过滤记录
`ArgosPacketListPage` SHALL 提供事件类型过滤器，允许用户在「全部 / 网络 / 崩溃 / 卡顿 / 资源」之间单选，仅展示所选类型的记录。过滤依据为 `ArgosPacketRecord.kind`。

#### Scenario: 选中某一事件类型只展示该类型记录
- **WHEN** 用户在事件类型过滤器中选中「崩溃」
- **THEN** 列表仅展示 `kind == 'crash'` 的记录，网络、卡顿与资源记录不出现

#### Scenario: 选中「全部」展示所有类型
- **WHEN** 用户选中「全部」
- **THEN** 列表展示所有 `kind` 的记录，不因类型而过滤

#### Scenario: 事件类型过滤器展示各类型条数
- **WHEN** 列表页渲染事件类型过滤器
- **THEN** 每个类型选项上展示选中该类型后实际会展示的记录条数（即已应用搜索关键词、但未应用类型过滤的结果集中该类型的条数），用户无需逐个选中即可得知各类型是否有记录

#### Scenario: 条数随搜索联动，不展示会被搜索过滤掉的记录
- **WHEN** 用户输入的搜索关键词排除了全部崩溃记录
- **THEN** 「崩溃」选项上的条数为 0，而非存储中崩溃记录的总数——该数字 MUST 与选中后实际可见的条数一致

### Requirement: Method 过滤降级为网络类型的二级过滤
HTTP Method 过滤器 SHALL 仅在事件类型为「全部」或「网络」时展示；当选中「崩溃」「卡顿」「资源」时，系统 SHALL 隐藏 Method 过滤器，避免产生必然为空的过滤组合。

#### Scenario: 选中网络类型时可用 Method 二级过滤
- **WHEN** 用户选中事件类型「网络」并进一步选中 Method「POST」
- **THEN** 列表仅展示 `kind == 'network'` 且 method 为 POST 的记录

#### Scenario: 选中非网络类型时隐藏 Method 过滤器
- **WHEN** 用户选中事件类型「卡顿」
- **THEN** Method 过滤器不展示，界面上不存在「卡顿 + GET」这类必然为空的组合

#### Scenario: 从网络切换到其他类型时重置 Method 选择
- **WHEN** 用户在 Method 为「POST」的状态下把事件类型切换为「崩溃」
- **THEN** Method 选择被重置为「ALL」，切回「网络」时不残留此前的 POST 过滤

### Requirement: APM 事件不因 Method 过滤而丢失
系统 SHALL NOT 因记录的 `method` 字段不是 HTTP 动词而将其从列表中过滤掉。非网络事件的可见性 MUST 仅由事件类型过滤器决定。

#### Scenario: 选中「全部」时 APM 事件可见
- **WHEN** 事件类型为「全部」，且存储中存在崩溃、卡顿、资源记录
- **THEN** 这些记录在列表中可见，不会因 Method 过滤器的默认值而被隐藏

### Requirement: 事件类型过滤与搜索、路由分组联动
事件类型过滤 SHALL 与 URL 关键词搜索、路由分组同时生效：三者为与（AND）关系，路由分组在过滤后的结果集上重新计算，空分组不展示。

#### Scenario: 类型过滤与搜索同时生效
- **WHEN** 用户选中事件类型「网络」并输入搜索关键词
- **THEN** 列表仅展示同时满足「kind 为 network」与「URL 包含关键词」的记录

#### Scenario: 过滤后空分组不展示
- **WHEN** 某个路由分组下的记录在类型过滤后全部被排除
- **THEN** 该分组不在列表中展示
