## ADDED Requirements

### Requirement: 列表页抓包开关按钮
`KurilPacketListPage` AppBar SHALL 提供一个图标按钮，实时显示并控制 `KurilApmManager.instance.captureEnabled` 状态。

#### Scenario: 开关图标反映当前状态
- **WHEN** 用户打开 `KurilPacketListPage`
- **THEN** AppBar 显示开关图标：抓包开启时显示暂停图标，关闭时显示录制图标

#### Scenario: 点击开关切换抓包状态
- **WHEN** 用户点击 AppBar 中的开关图标
- **THEN** `KurilApmManager.instance.captureEnabled` 取反，图标随之更新
