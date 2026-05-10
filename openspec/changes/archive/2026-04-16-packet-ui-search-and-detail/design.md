## Context

**列表页现状：** 静态列表，每次从 `KurilPacketStorage.getAll()` 加载全量数据，无搜索/过滤。

**详情页现状：** 单列 `ListView`，`_row(label, value)` 使用 `SizedBox(width: 80)` 固定 label 宽度，对长 header key 不友好。请求与响应信息混排，`error` 字段无特殊处理。

## Goals / Non-Goals

**Goals:**
- 列表页内存过滤（不读存储），响应用户输入立即更新
- 详情页 Tab 结构：减少单页滚动，请求/响应分区明确
- Header 展示自适应，不截断
- 错误请求有视觉区分

**Non-Goals:**
- 不支持持久化过滤条件（关闭页面后不保留）
- 不修改 `KurilPacketStorage` 层（过滤在内存 UI 层完成）
- 不实现多选删除等高级操作

## Decisions

### 决策 1：列表页过滤在内存中完成

`_KurilPacketListPageState` 维护两个状态：`_allRecords`（原始全量）和 `_filtered`（当前展示）。搜索/过滤条件变化时在内存中重新 filter，不重新读 MMKV。优点：响应快，无 I/O；缺点：数据量极大时有内存压力，但 `maxPacketRecords` 默认 200，可接受。

### 决策 2：搜索栏 + Method chip 组合

搜索栏使用 `TextField` 内嵌在 `AppBar.bottom` 的 `PreferredSize` 中，保持 AppBar 标题不变。Method chip 行放在列表顶部（`SliverAppBar` 或 `Column` 顶部 padding 区域），选项：`ALL / GET / POST / PUT / DELETE / 其他`（合并低频方法）。

### 决策 3：详情页使用 `DefaultTabController` + `TabBarView`

`AppBar` 中加 `TabBar`（两个 tab：请求/响应），`body` 为 `TabBarView`。两个 tab 各自是独立 `ListView`，内容解耦。

### 决策 4：Header 展示改为上下排列

抛弃固定宽 label 列，改为：
```
key（灰色小字）
value（全宽可选文本）
```
每个 header item 是一个 `Padding + Column`，key 和 value 各占一行。视觉上更清晰，长 key 也不会截断。

### 决策 5：错误卡片置于响应 Tab 顶部

`record.error != null` 时，在响应 Tab 最顶部插入一个 `Card`（红色边框），展示 error 文字。下方仍展示 `responseCode: 0`，方便对比。

## Risks / Trade-offs

- **Tab 状态不保留**：从详情页返回列表再进入时，tab 重置为请求 tab。对调试场景影响不大。
- **搜索不支持正则**：纯字符串 contains 过滤，满足大多数调试场景，复杂需求可后续扩展。
