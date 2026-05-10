## Context

两个页面目前的 AppBar 都是最简单的 `AppBar(title: Text(...))` 调用，完全依赖 Flutter 的 `ThemeData.primaryColor`。没有渐变、没有自定义布局、TabBar 使用默认白色下划线指示器。

改动只涉及两个 Dart 文件的 Widget 构建逻辑，不影响业务代码。

## Goals / Non-Goals

**Goals:**
- 列表页 AppBar 使用 `flexibleSpace` 渐变背景（`Colors.indigo.shade700` → `Colors.blue.shade600`）
- 列表页标题行左侧加 `Icons.wifi_tethering` 小图标
- 搜索框改为白色半透明描边（`border: OutlineInputBorder` with `BorderSide(color: Colors.white54)`），去掉 filled 背景
- 详情页 AppBar 标题改为 `Row`：左侧 Method Badge（复用 `_methodColor` 逻辑）+ 右侧 URL 文字
- TabBar 使用圆角胶囊指示器（`BoxDecoration` indicator）、标签颜色 `white70` / 选中 `white`

**Non-Goals:**
- 不做主题级别（`ThemeData`）的全局修改
- 不支持深色模式
- 不抽取独立的 AppBar Widget 类（改动集中在两个文件，不需要共享组件）

## Decisions

### 决策 1：渐变用 `flexibleSpace` + `Container` 而非 `backgroundColor`

`AppBar.backgroundColor` 只接受单色。用 `flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(...)))` 是 Flutter 标准做法，且不影响 `elevation`、`centerTitle` 等其他属性。

### 决策 2：不单独抽取 `_methodColor` 到公共文件

`argos_packet_detail_page.dart` 自己内联一个相同的颜色映射函数，保持文件独立。两个文件都是内部实现，重复定义可以接受，不引入新文件。

### 决策 3：TabBar indicator 用 `ShapeDecoration` + `StadiumBorder`

Flutter 内置 `UnderlineTabIndicator` 的圆角胶囊效果差，改用：
```dart
indicator: ShapeDecoration(
  shape: StadiumBorder(),
  color: Colors.white24,
)
```
简洁且无需自定义 `Decoration` 子类。

## Risks / Trade-offs

- `flexibleSpace` 在 `SliverAppBar` 下行为不同，但这里只用普通 `AppBar`，无风险。
- 渐变颜色写死（`Colors.indigo.shade700`）——接入方无法通过 `ThemeData` 覆盖。可接受，因为这是调试工具页面。
