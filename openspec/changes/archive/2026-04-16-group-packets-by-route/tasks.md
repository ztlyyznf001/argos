## 1. 数据模型与存储

- [x] 1.1 在 `KurilPacketRecord` 中新增 `routeName` 字段（`String`，默认空字符串），更新构造函数、`fromJson`（缺失时降级为 `''`）和 `toJson`
- [x] 1.2 在 `KurilApmManager` 中新增可写属性 `currentRoute`（`String`，初始值为 `''`）
- [x] 1.3 在 `_dispatchHttpInfo` 中将 `KurilApmManager.instance.currentRoute` 注入到 `KurilPacketStorage.instance.append` 调用，使记录携带路由快照

## 2. 存储层适配

- [x] 2.1 更新 `KurilPacketStorage.append` 方法签名以接收并写入 `routeName`，或由 `KurilPacketRecord.fromHttpInfo` 在构建时注入

## 3. UI — 路由分组展开列表

- [x] 3.1 将 `KurilPacketListPage` 的平铺列表改为按 `routeName` 分组的结构：派生出有序的分组列表（空字符串映射为"未知页面"，放在末尾）
- [x] 3.2 用 `ExpansionTile` 渲染每个路由分组，标题显示路由名称和记录条数，默认展开，组内按原有行样式渲染各记录
- [x] 3.3 搜索栏或 Method 过滤变更时重新计算各分组内容，过滤后记录为空的分组隐藏
- [x] 3.4 数据刷新后（从详情页返回）重新生成分组，所有分组重置为默认展开

## 4. 验证

- [x] 4.1 为 `KurilPacketRecord` 补充 `routeName` 序列化/反序列化单元测试，覆盖旧数据缺失 `routeName` 的降级场景
- [x] 4.2 手工验证：在宿主 App 中通过 `NavigatorObserver` 更新 `currentRoute`，抓包记录展示正确路由分组
