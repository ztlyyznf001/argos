## MODIFIED Requirements

### Requirement: 友好的空状态展示
当列表无记录或无匹配记录时，SHALL 展示一个图标加说明文字的空状态视图，替代纯文字提示。空状态的图标与文案 SHALL 依据当前选中的事件类型给出对应提示，MUST NOT 一律假设记录为网络抓包。

#### Scenario: 无记录时展示图标空状态
- **WHEN** 存储中没有任何记录，且事件类型为「全部」
- **THEN** 页面展示一个图标和"暂无记录"文字，垂直居中

#### Scenario: 空状态按事件类型给出对应文案
- **WHEN** 用户选中事件类型「崩溃」，但存储中没有任何崩溃记录
- **THEN** 页面展示与崩溃对应的图标与文案（如"暂无崩溃记录"），而非"暂无抓包记录"

#### Scenario: 无匹配时展示图标空状态
- **WHEN** 搜索或过滤后没有匹配的记录
- **THEN** 页面展示一个图标和"无匹配记录"文字，垂直居中

## ADDED Requirements

### Requirement: 暗色模式下的取色与对比度
Inspector 界面的次要文字、分隔线、卡片背景与表面色 SHALL 从 `Theme.of(context).colorScheme` 取值（如 `onSurfaceVariant`、`outlineVariant`、`surfaceContainer`），MUST NOT 硬编码固定灰阶（如 `Colors.grey`），以保证浅色与深色模式下均具备足够对比度。

#### Scenario: 深色模式下次要文字可读
- **WHEN** 宿主应用运行在深色主题下，用户打开 Inspector
- **THEN** 列表项的时间、耗时等次要文字与背景保持足够对比度，不出现灰底灰字

#### Scenario: 卡片与分隔线跟随主题
- **WHEN** 宿主应用在浅色与深色主题之间切换
- **THEN** 卡片背景与分隔线的颜色随 `ColorScheme` 相应变化

### Requirement: 语义色不跟随主题变化
HTTP Method 的语义色（GET 蓝 / POST 绿 / PUT 橙 / DELETE 红 / PATCH 紫）与事件类型的语义色（崩溃红 / 卡顿橙 / 资源青）SHALL 保持固定色相，MUST NOT 从 `ColorScheme` 派生——它们是携带信息的编码而非主题装饰。在深色模式下 MAY 调整其明度以保证对比度，但色相 MUST 保持一致。

#### Scenario: 深色模式下 DELETE 仍为红色系
- **WHEN** 应用切换到深色主题
- **THEN** DELETE 的 Method Badge 仍呈红色系，仅明度按需调整，不因主题而变为其他色相

#### Scenario: 崩溃事件在任何主题下均为红色系
- **WHEN** 列表中展示一条崩溃记录，无论浅色或深色主题
- **THEN** 其图标与类型标签均为红色系，保持"红色 = 危险"的一致语义

### Requirement: 事件类型的图标与标签规范
崩溃、卡顿、资源三类事件 SHALL 各自具备稳定的语义化图标与中文类型标签，在列表项与详情页标题中保持一致，使用户能够一眼区分事件类型。

#### Scenario: 三类事件具备可区分的图标
- **WHEN** 列表中同时存在崩溃、卡顿、资源三类记录
- **THEN** 每类记录展示各自不同的图标与类型标签（崩溃 / 卡顿 / 资源），彼此可一眼区分

#### Scenario: 列表与详情页的图标标签一致
- **WHEN** 用户从列表点击一条卡顿记录进入详情页
- **THEN** 详情页标题栏展示的图标与类型标签与列表项中的一致
