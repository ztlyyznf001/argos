## Why

`ArgosPacketDetailPage` 的"复制 cURL"按钮放在 AppBar 右侧以纯文本 `TextButton` 呈现，在白色或浅色主题下与 AppBar 背景对比度不足，容易被忽略。此外，调试时经常需要复制响应体（如 JSON），目前只能手动长按选中，没有一键复制入口。

## What Changes

- **复制 cURL 按钮改为图标按钮**：用 `IconButton(icon: Icon(Icons.copy))` 替换 `TextButton('复制 cURL')`，视觉更清晰，加 tooltip 说明功能
- **新增复制响应体按钮**：在响应 Tab 的响应体区块标题右侧添加复制图标按钮，点击后将格式化后的响应体写入剪贴板并显示 SnackBar 提示

## Capabilities

### New Capabilities

_(无)_

### Modified Capabilities

- `packet-record-ui`：更新"复制请求为 cURL 命令"需求（按钮形式改变）+ 新增"复制响应体"需求

## Impact

- `lib/ui/argos_packet_detail_page.dart`：AppBar action 改为 `IconButton`，响应体区块标题行添加复制按钮
