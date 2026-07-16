## Context

Inspector 的两个页面都是在只有 HTTP 抓包时设计的：

- `lib/ui/argos_packet_list_page.dart`（596 行）：`_methods = ['ALL','GET','POST','PUT','DELETE']` 驱动唯一的一排过滤 chip；`_filtered` 用 `r.method.toUpperCase() == _selectedMethod` 过滤。APM 事件的 `method` 不是 HTTP 动词，所以任何具体 method 被选中时它们都会被过滤掉。列表项已有 `_buildApmItem` 分支（按 `record.kind` 给出图标/标签/配色），说明混合流已经开始，但过滤器、空状态、标题都还停留在网络语义。
- `lib/ui/argos_packet_detail_page.dart`（464 行）：`DefaultTabController(length: 2)` 固定「请求 / 响应」两个 Tab，标题是 method 徽标 + `_shortUrl(uri)`。只有 `record.kind == 'network'` 时才显示复制 cURL 按钮——这是目前唯一一处对 kind 的让步，其余结构对崩溃/卡顿/资源完全不适用。

数据侧：`ArgosPacketRecord` 是一个扁平结构（`kind`、`uri`、`method`、`startTimestamp`、`responseCode`、`responseSize`、`responseBody`、`error`、`routeName` 等），四类事件共用同一张表，APM 事件把各自的载荷塞进既有字段。`responseSize` 已存在但列表未展示。

关键约束：资源监控 `resourceSampleInterval` 默认 2 秒（`lib/config/argos_config.dart:40`），每次采样产生一条独立记录并落盘。

## Goals / Non-Goals

**Goals:**
- 让列表能按事件类型过滤，且资源采样不再淹没其他事件。
- 让每类事件都有与其语义匹配的详情展示。
- 提升列表信息密度与暗色模式下的可读性。

**Non-Goals:**
- 不改动 `lib/apm/` 的采集逻辑、`lib/model/` 的数据模型与 `ArgosPacketStorage` 的存储行为。本次是纯展示层变更——采样频率、落盘策略、存储配额都不动（见「Risks」中对存储压力的说明）。
- 不引入图表库；资源趋势用轻量的自绘 sparkline 或纯文本数值表达即可。
- 不改动公开 API 与宿主接入方式。
- 不做国际化抽取；文案继续沿用中文硬编码，与现有代码一致。

## Decisions

### 决策一：两级过滤，而不是把事件类型混进现有 Method chip 排

把 `崩溃/卡顿/资源` 直接追加到 `['ALL','GET','POST',...]` 这一排里最省事，但会把两个正交的维度（**事件类型** 与 **HTTP 动词**）挤进一个单选组——用户将无法表达「网络 + POST」这种组合，且 chip 数量膨胀到 8 个。

改为两级：第一级为事件类型单选（全部/网络/崩溃/卡顿/资源），第二级 Method chip **仅在第一级选中「网络」或「全部」时显示**。选中「崩溃」时 Method 过滤失去意义，直接隐藏，避免出现「选了崩溃又选了 GET 结果空列表」的死角。各类型 chip 附带当前条数，让用户不必逐个点开就知道哪里有东西。

### 决策二：资源采样在**展示层**聚合，不动采集与存储

治本的做法是降低采样落盘频率或给资源事件单独的存储配额，但那会改变 `resource-monitor` 与 `packet-storage` 的既有需求，属于另一个变更的范畴，且会牺牲数据完整性（用户可能确实想要 2 秒粒度的原始采样）。

本次只在列表渲染时把**时间上连续相邻**的资源采样折叠成一个聚合项：聚合项显示区间时间范围、采样条数、当前 RSS、峰值 RSS 与一条趋势 sparkline；点击展开可看到逐条原始采样。「连续相邻」的判定为：在按时间排序的记录流中，相邻两条资源记录之间没有夹杂其他类型的事件——一旦出现 HTTP 请求或崩溃，聚合就断开，这样资源基线与它前后发生的事件仍能在时间线上对上，不会因聚合而丢失因果关系。

代价是存储压力依然存在（1800 条/小时仍会挤占 `packet-storage` 的条数上限），这一点在 proposal 的 Impact 中明确记录，留待后续变更处理。

### 决策三：详情页按 `kind` 分派到不同视图，而不是给 Tab 打补丁

`DefaultTabController(length: 2)` 是写死的。与其在「请求/响应」两个 Tab 内部按 kind 塞不同内容（会得到一个语义错乱的容器），不如让 `ArgosPacketDetailPage` 退化为一个分派器：`network` 走现有的 `_RequestTab`/`_ResponseTab` 双 Tab 结构（完全保留，零回归风险）；`crash`/`jank`/`resource` 各自走一个单页的、无 Tab 的类型化视图。标题栏同样按 kind 分派——网络显示 method 徽标 + URL，APM 事件显示类型徽标 + 事件摘要。

这是一个**行为破坏**：崩溃/卡顿/资源记录不再有「请求/响应」Tab。但那两个 Tab 对这些事件本就是空的、无意义的，移除是修正而非损失。

### 决策四：配色统一走 `ColorScheme`，但保留 method/kind 的语义色

现有代码大量硬编码 `Colors.grey`、`Colors.red` 与固定深色渐变 `[0xFF1A1A2E, 0xFF16213E]`，暗色模式下灰阶对比度不足。次要文字、分隔线、卡片背景改为从 `Theme.of(context).colorScheme` 取（`onSurfaceVariant`、`outlineVariant`、`surfaceContainer` 等）。

但 method 的语义色（GET 蓝 / POST 绿 / DELETE 红…）与 kind 的语义色（崩溃红 / 卡顿橙 / 资源青）**不走 ColorScheme**——它们是携带信息的编码，不是主题装饰，跟随主题变化反而会破坏「红色 = 危险」的固有认知。这两组色板保持固定色值，仅在暗色模式下按需调整明度以保证对比度。

### 决策五：相对时间与绝对时间并列，而非二选一

只显示相对时间（「2 分钟前」）会丢失排查时对齐日志所需的精确时刻；只显示绝对时间则难以快速判断新鲜度。列表项同时给出 `2 分钟前 · 14:03:22`。相对时间需要随时间推移刷新，但**不引入定时器**——列表本就在 `_load()` 后 `setState`，且用户进出详情页会触发重建，陈旧的相对时间不构成正确性问题，不值得为此付出一个常驻 Timer 的代价。

## Risks / Trade-offs

- **[聚合逻辑可能把不该合并的资源采样合到一起，掩盖某次内存尖峰]** → 聚合项必须展示区间内的**峰值** RSS 而不只是均值或末值，尖峰在折叠态就可见；且聚合可展开还原为逐条原始采样，不丢数据。
- **[详情页移除 APM 事件的「请求/响应」Tab 是破坏性变更]** → 这两个 Tab 对 APM 事件本就是空白，实际不存在依赖它们的使用场景；在 proposal 中以 **BREAKING** 明确标注。
- **[展示层聚合掩盖了存储层的真实压力，可能让人误以为问题已解决]** → 在 proposal 的 Impact 与本文档中都明确写下：1800 条/小时的存储占用**未被解决**，只是不再刺眼；后续需单独评估采样落盘频率或资源事件独立配额。
- **[改动集中在两个大文件（596 + 464 行），回归面较大]** → 网络记录的展示路径（列表项、请求/响应双 Tab、cURL 复制）保持原有结构不动，改动限定在新增分支与取色方式上；`flutter analyze` 零告警 + 用 example 的 APM demo 页逐类事件手工验证。
- **[两级过滤增加了状态组合，可能出现空列表死角]** → 选中非「网络」类型时隐藏 Method 过滤（决策一），从结构上消除「崩溃 + GET」这类必然为空的组合。
