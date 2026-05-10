## Context

`KurilPacketListPage` 和 `KurilPacketDetailPage` 是开发者调试时频繁使用的工具页面。当前实现功能完备，但视觉设计停留在"够用"层面：列表项是简单的 `InkWell + Padding`，无卡片层次；Method 标签只是小色块文字；状态码直接显示数字。对于需要在数十条请求中快速定位问题的开发者来说，视觉噪音高、扫描效率低。

改动范围仅限 UI 层（两个 `.dart` 文件），不涉及数据模型、存储或拦截逻辑。

## Goals / Non-Goals

**Goals:**
- 列表项升级为卡片样式，增加视觉层次感
- Method Badge 使用语义化颜色系统（GET=蓝、POST=绿、PUT=橙、DELETE=红、PATCH=紫）
- 状态码以 Chip 样式展示，色系与现有 `_statusColor` 逻辑保持一致
- 慢请求耗时（>1000ms）高亮为橙/红色
- 路由分组 Header 增加左侧色块 accent 装饰
- 空状态展示图标 + 更友好的说明文字
- 详情页各区块用 Card 包裹，信息密度适中

**Non-Goals:**
- 不引入任何新的 pub 依赖（包括语法高亮库）
- 不改变任何功能行为或数据流
- 不添加深色模式支持（当前项目未启用）
- 不改变导航结构或页面路由

## Decisions

### 决策 1：不引入第三方 UI 依赖

**选项 A**（选用）：仅使用 Flutter Material 内置 Widget（`Card`、`Chip`、`Container` with decoration 等）

**选项 B**：引入 `flutter_syntax_view` 或类似库做代码高亮

**理由**：这是一个 SDK 包（不是 App），引入额外依赖会增加接入方的负担，且 `pubspec.yaml` 约束严格。纯 Material 实现足以达到目标颜值。

### 决策 2：Method Badge 颜色映射表集中管理

在 `_PacketListItem`（或抽取为顶层函数）中定义 `const Map<String, Color> _methodColors`，覆盖常见方法，未识别方法回退到 `Colors.blueGrey`。

**理由**：颜色逻辑集中，易于后续扩展，避免散落在多处。

### 决策 3：列表项使用 Card + margin，不用全局 ListView separator

将每个 `_PacketListItem` 包装在 `Card(margin: EdgeInsets.symmetric(horizontal:12, vertical:4))` 中，取消 `Divider`。

**理由**：Card 自带阴影和圆角，视觉层次更清晰；去掉分割线减少视觉噪音。路由分组 Header 本身作为 section 分隔。

### 决策 4：慢请求阈值硬编码为 1000ms

不暴露为配置项。调试工具的"慢"定义在大多数场景下 1s 是合理边界。

### 决策 5：详情页 Card 使用 `elevation: 0` + 边框

`Card(elevation:0, shape: RoundedRectangleBorder(...))` 配合 `Theme.of(context).dividerColor` 边框，避免多层阴影叠加显得厚重。

## Risks / Trade-offs

- **Widget 树深度增加** → 每个列表项多一层 Card，在数百条记录时有轻微渲染开销。可接受，因为 `ListView.builder` 已做懒加载。
- **颜色在深色主题下可能不协调** → 当前项目无深色模式需求，暂不处理；若未来支持深色模式需重新审视硬编码颜色。
