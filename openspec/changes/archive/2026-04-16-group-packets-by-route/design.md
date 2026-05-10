## Context

当前 `KurilPacketRecord` 只记录请求本身的字段（URI、Method、Headers、Body 等），没有页面上下文。`KurilPacketListPage` 展示的是一条全局混合列表，无法区分请求来自哪个路由。宿主 App 与监控库之间目前只通过 `KurilApmManager.config` 和 `listener` 进行单次初始化通信，没有运行时状态更新通道。

## Goals / Non-Goals

**Goals:**
- 在 `KurilPacketRecord` 中持久化路由名称
- 提供宿主 App 随路由变更实时更新当前路由的接口
- 列表页支持按路由分组展示，且保留"全部"视图
- 对旧存储数据向后兼容（`routeName` 缺失时降级为空字符串）

**Non-Goals:**
- 自动感知路由变化（不接管 Navigator，宿主主动推送）
- 支持嵌套路由或多 Navigator 场景的精确路由追踪
- 按路由过滤的持久化偏好存储

## Decisions

### 1. currentRoute 挂载在 KurilApmManager 上
宿主 App 在 `NavigatorObserver.didPush/didPop` 时调用 `KurilApmManager.instance.currentRoute = routeName`。选择挂载在已有单例上，而非新增全局变量，保持 API 一致性。不侵入 Flutter 路由系统，不要求宿主使用特定 Navigator 实现。

### 2. routeName 在 _dispatchHttpInfo 写入时快照
请求发出到响应完成之间路由可能已切换。选择在 `_dispatchHttpInfo`（响应完成时）读取 `currentRoute` 快照，而不是在请求发出时。这样记录的是"哪个页面等到了这个响应"，对调试更有意义；且实现最简单，无需在请求生命周期内传递路由上下文。

### 3. KurilPacketRecord.routeName 类型为 String（默认空字符串）
不使用 `String?` nullable，避免下游代码处处判空。旧数据反序列化时 `json['routeName'] as String? ?? ''` 安全降级。空字符串在 UI 层统一归入"未知页面"分组。

### 4. 列表页分组方案：可展开/折叠的分组列表
使用 `ExpansionTile` 将记录按 `routeName` 分组，每个分组标题显示路由名称和该分组的记录条数，点击可展开/折叠。空字符串归入"未知页面"分组。默认全部展开。

选择展开折叠列表而非 Tab，原因：
- 所有分组在同一视图中一览无余，无需在 Tab 间切换
- 路由数量多时不会出现横向滚动 Tab 栏的空间问题
- 折叠后可快速定位目标分组，展开后可直接查看记录

与搜索栏 + Method 过滤的协作：过滤条件改变时重新计算各分组内容，分组为空时隐藏该分组。

## Risks / Trade-offs

- **路由快照时机**：`_dispatchHttpInfo` 在响应 `onDone` 时触发，此时路由可能已离开请求发出时的页面。对大多数场景（短请求）影响可忽略，长轮询或后台请求可能归入错误分组 → 可接受，文档说明即可。
- **分组后无法排序**：展开折叠列表按路由分组，组内按时间倒序，但无法全局排序 → 搜索栏 + Method 过滤可弥补定位需求。
- **旧数据兼容**：已存储记录无 `routeName` 字段，反序列化默认空字符串，归入"未知页面"分组 → 行为符合预期，无需迁移。

## Migration Plan

无存储格式版本号，采用软兼容：`fromJson` 中 `routeName` 缺失时降级为 `''`，不破坏现有记录读取。`toJson` 始终写入 `routeName` 字段（即使为空字符串）。
