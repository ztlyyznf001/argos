## Context

`ArgosPacketDetailPage` 当前 AppBar：
```dart
actions: [
  TextButton(
    onPressed: () => _copyCurl(context),
    child: const Text('复制 cURL', style: TextStyle(color: Colors.white)),
  ),
],
```

响应体由 `_BodySection` Widget 渲染，标题行是独立的 `_SectionTitle`，内容区是带背景色的 `SelectableText`。

## Goals / Non-Goals

**Goals:**
- AppBar 复制 cURL 改为图标按钮，视觉更突出
- 响应体标题行右侧加复制按钮，一键复制格式化后的响应内容

**Non-Goals:**
- 不修改复制逻辑本身（仍用 `Clipboard.setData`）
- 不在请求体添加复制按钮（需求只涉及响应体）

## Decisions

### 决策 1：AppBar 改为 `IconButton`

```dart
IconButton(
  icon: const Icon(Icons.copy, color: Colors.white),
  tooltip: '复制 cURL',
  onPressed: () => _copyCurl(context),
)
```

图标比文字在 AppBar 中更紧凑，`tooltip` 保留文字说明，符合 Material Design 规范。

### 决策 2：响应体标题行改为 `Row`

`_BodySection` 的标题行由 `_SectionTitle` 独占改为：
```
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [_SectionTitle(title), IconButton(copy)]
)
```

只在 `_ResponseTab` 的响应体 `_BodySection` 上加复制，请求体不加。为此需要给 `_BodySection` 增加可选 `onCopy` 回调参数，非空时才渲染复制按钮。

## Risks / Trade-offs

- 响应体可能很大（已有 100KB 截断），复制时会把整个字符串写入剪贴板，系统层面可接受。
- `_BodySection` 增加可选参数，不影响现有调用方（`requestBody` 调用不传 `onCopy`）。
