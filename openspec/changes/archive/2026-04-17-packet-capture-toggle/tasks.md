## 1. 核心逻辑

- [x] 1.1 在 `KurilApmManager` 中新增 `captureEnabled` 属性（`bool`），在 `init()` 中赋初始值为 `config?.enableStorage ?? false`
- [x] 1.2 在 `_dispatchHttpInfo` 入口处增加 `if (!manager.captureEnabled) return;` 判断，关闭时跳过 listener 和 storage

## 2. UI

- [x] 2.1 在 `KurilPacketListPage` 状态中读取 `KurilApmManager.instance.captureEnabled`，AppBar 新增图标按钮（开启时 `Icons.pause_circle`，关闭时 `Icons.fiber_manual_record`），点击时取反并 `setState`

## 3. 验证

- [x] 3.1 手工验证：在列表页点击开关后，新发出的请求不再出现在列表中；再次点击开启后请求恢复记录
