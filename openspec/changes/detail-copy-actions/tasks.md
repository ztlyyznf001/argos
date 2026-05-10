## 1. AppBar 复制 cURL 改为图标按钮

- [x] 1.1 将 `ArgosPacketDetailPage` AppBar actions 中的 `TextButton('复制 cURL')` 替换为 `IconButton(icon: Icon(Icons.copy), tooltip: '复制 cURL', onPressed: ...)`

## 2. 响应体复制按钮

- [x] 2.1 给 `_BodySection` 添加可选参数 `ValueChanged<String>? onCopy`，用于把当前展示的格式化响应体传给复制回调
- [x] 2.2 当 `onCopy != null` 时，将标题区渲染为带复制按钮的 `Row`，右侧加 `IconButton(Icons.copy_outlined, onPressed: () => onCopy!(formatted))`
- [x] 2.3 在 `_ResponseTab` 的响应体 `_BodySection` 调用处传入 `onCopy`，回调内执行 `Clipboard.setData` 复制格式化后的响应体，并显示"已复制响应体" SnackBar

## 3. 验证

- [x] 3.1 运行 `dart analyze lib/ui/` 无新增错误
