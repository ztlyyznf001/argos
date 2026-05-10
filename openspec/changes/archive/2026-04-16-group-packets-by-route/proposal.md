## Why

抓包列表当前展示所有请求的混合列表，无法区分请求来自哪个页面。调试时需要人工过滤，尤其在多页面并发发请求时难以定位目标。通过在捕获时记录当前路由，可在列表页按页面分组展示，大幅提升调试效率。

## What Changes

- `KurilPacketRecord` 新增 `routeName` 字段（可为空字符串），记录请求发出时所在的页面路由
- `KurilApmManager` 新增 `currentRoute` 可写属性，宿主 App 通过 `RouteObserver` 或 `NavigatorObserver` 在路由变更时更新该值
- `_dispatchHttpInfo` 在写入存储时将 `KurilApmManager.instance.currentRoute` 注入到记录中
- `KurilPacketListPage` 新增路由分组视图：顶部 Tab 或分组列表，按 `routeName` 聚合记录；保留原有"全部"入口
- 无 `routeName`（空字符串）的记录归入"未知页面"分组

## Capabilities

### New Capabilities

- `packet-route-grouping`: 按路由对抓包记录分组展示的 UI 能力

### Modified Capabilities

- `packet-storage`: `KurilPacketRecord` 新增 `routeName` 字段，影响序列化/反序列化格式
- `packet-record-ui`: 列表页新增路由分组视图

## Impact

- `lib/model/kuril_http_info_model.dart`: `KurilPacketRecord` 增加 `routeName` 字段
- `lib/kuril_apm_manager.dart`: 增加 `currentRoute` 属性
- `lib/apm/kuril_http_monitor.dart`: `_dispatchHttpInfo` 写入时注入 `currentRoute`
- `lib/ui/kuril_packet_list_page.dart`: 新增分组视图逻辑
- `lib/storage/kuril_packet_storage.dart`: JSON 序列化兼容旧数据（`routeName` 缺失时降级为空字符串）
