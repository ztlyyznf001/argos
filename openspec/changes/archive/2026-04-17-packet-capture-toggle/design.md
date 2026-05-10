## Context

`_dispatchHttpInfo` 目前在 `captureEnabled` 判断前无条件写入存储和触发 listener。`KurilApmConfig.enableStorage` 是初始化时的静态配置，运行时不可变。`KurilApmManager` 已有 `currentRoute` 等运行时可写属性，模式一致。

## Goals / Non-Goals

**Goals:**
- 运行时可随时通过 `KurilApmManager.instance.captureEnabled = false/true` 暂停/恢复抓包
- 列表页提供开关按钮，直观控制状态
- 初始值与 `enableStorage` 保持一致，无破坏性变更

**Non-Goals:**
- 持久化开关状态（App 重启后重置为 `enableStorage` 的值）
- 控制网络拦截本身（拦截链路始终运行，只控制是否写入/回调）
- 单独控制 listener 与 storage 的开关

## Decisions

### 1. captureEnabled 挂载在 KurilApmManager
与 `currentRoute` 保持一致，运行时状态统一由 `KurilApmManager` 持有。初始值在 `init()` 时赋为 `config.enableStorage`，使旧行为无缝兼容。

### 2. 开关作用于 _dispatchHttpInfo 整体
`captureEnabled == false` 时，`_dispatchHttpInfo` 在入口处直接 return，同时跳过 listener 和 storage。保持逻辑简单，避免 listener 收到但 storage 不写（或反之）造成状态不一致。

### 3. UI 开关放在列表页 AppBar
列表页是调试入口，开关放在右上角图标按钮（`Icons.pause_circle` / `Icons.play_circle`），与"清空"按钮并排。开关状态直接读写 `KurilApmManager.instance.captureEnabled`，无需额外状态管理。

## Risks / Trade-offs

- **关闭期间的请求不补录**：`captureEnabled` 为 false 时发出的请求不会在重新开启后补记录 → 符合预期，开关语义就是"暂停"
- **listener 也被屏蔽**：关闭开关后宿主 App 的 listener 也不会收到回调 → 与存储行为保持一致，避免歧义；如有需要可后续拆分
