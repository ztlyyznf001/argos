## MODIFIED Requirements

### Requirement: 清空所有记录操作
列表页 SHALL 提供清空所有诊断会话、会话 records 和未归属历史记录的操作入口。确认清空 SHALL 调用统一 clear 流程，并同步结束活动会话、把页面录制状态更新为 idle。

#### Scenario: 用户清空记录
- **WHEN** 用户在列表页点击“清空”并确认
- **THEN** 系统清空新版与 legacy 存储 key、sessions 和 records，列表刷新为空，activeSession 为空且抓包按钮显示未录制状态

#### Scenario: 用户取消清空
- **WHEN** 用户点击清空后在确认弹窗中取消
- **THEN** 不执行清空，列表、activeSession 与 captureEnabled 状态保持不变

### Requirement: 列表页抓包开关按钮
`ArgosPacketListPage` AppBar SHALL 保留图标按钮并实时反映 `ArgosManager.instance.captureEnabled`。按钮关闭时 SHALL 暂停当前诊断会话，按钮重新开启时 SHALL 恢复同一 paused 会话；idle 状态开启时 SHALL 创建新会话。

#### Scenario: 开关图标反映当前状态
- **WHEN** 用户打开列表页
- **THEN** sessionState 为 recording 时显示暂停图标，paused 或 idle 时显示开始录制图标

#### Scenario: recording 时点击暂停
- **WHEN** 用户在 recording 状态点击抓包按钮
- **THEN** captureEnabled 变为 false、activeSession 保留为 paused，按钮切换为开始录制图标

#### Scenario: paused 时点击恢复
- **WHEN** 用户在 paused 状态点击抓包按钮
- **THEN** captureEnabled 变为 true、原 activeSession 恢复 recording，按钮切换为暂停图标

#### Scenario: idle 时点击开始
- **WHEN** 用户在 idle 状态点击抓包按钮
- **THEN** 系统创建新 activeSession 并开始 recording，按钮切换为暂停图标
