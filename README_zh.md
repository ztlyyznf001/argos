# Argos

> 全视角的 Flutter 性能监控 + HTTP 抓包插件。
>
> 名字取自希腊神话百眼巨人 Argus Panoptes ——Argos 看见你 App 的每一次请求。

[English README](README.md) · MIT 协议 · Flutter ≥ 3.0

## 特性

- **原生抓包** — iOS 通过 `NSURLProtocol`、Android 通过 `OkHttp Interceptor` 在原生层捕获流量，覆盖 Dart `HttpClient` 之外的请求路径
- **Dart 抓包** — 基于 `HttpOverrides`，覆盖所有走 `dart:io` HTTP 的代码路径
- **内置记录查看器** — 提供 `ArgosPacketListPage` / `ArgosPacketDetailPage` 页面，支持按路由分组、Method 过滤、URL 搜索、运行时开关、cURL 复刻
- **手机端 Widget Inspector** — 在 iOS / Android 上长按界面即可查看对应 Flutter Widget 的 Key、诊断属性和布局边界，也可通过悬浮入口浏览完整层级
- **可插拔存储** — `ArgosStorageAdapter` 接口允许你用 MMKV / SharedPreferences / 文件 / 自研引擎承载抓包日志
- **动态代理** — `ArgosConfig.proxyProvider` 接入调试代理开关，运行时可替换
- **FPS 监控** — 通过 `ArgosCapability.fps` 启用帧率采样
- **崩溃/错误捕获** — 通过 `ArgosCapability.crash` 启用，捕获 Flutter 框架错误（`FlutterError.onError`）与未处理的 Dart 异步异常（`PlatformDispatcher.onError`），并链式保留宿主已安装的 handler
- **卡顿分析** — 通过 `ArgosCapability.jank` 启用，基于帧预算检测掉帧、拆分 build/raster 耗时，并将连续掉帧聚合为卡顿区间事件
- **资源监控** — 通过 `ArgosCapability.resource` 启用，周期性采样进程内存（`ProcessInfo.currentRss` / `maxRss`）；纯 Dart 无法可靠获取 CPU 时该字段留空

以上三类均为纯 Dart 实现，不引入第三方依赖，与网络抓包共用同一 `ArgosManager.listener` 回调、存储与查看器 UI。

## 安装

```yaml
dependencies:
  argos_inspector: ^0.3.1
```

## 快速上手

```dart
import 'package:argos_inspector/argos_inspector.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ArgosManager.instance.init(
    config: ArgosConfig(
      apmTypes: [ArgosCapability.network],
      enableStorage: true,
      maxPacketRecords: 200,
    ),
    listener: (ArgosBaseModel? model) {
      debugPrint(model?.getValue());
    },
  );

  // 可选：启用原生抓包（iOS NSURLProtocol + Android OkHttp）
  ArgosNativeCapture.instance.enable();

  runApp(const MyApp());
}
```

打开查看器：

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const ArgosPacketListPage()),
);
```

## 手机端 Widget Inspector

如需悬浮调试入口，把 `ArgosWidgetInspector` 组合到
`MaterialApp.builder` 中。它会自动找到 App 的 Navigator，不需要额外提供
navigator key 或注册命名路由：

```dart
import 'package:flutter/foundation.dart';
import 'package:argos_inspector/argos_inspector.dart';

MaterialApp(
  builder: (context, child) => ArgosWidgetInspector(
    enabled: kDebugMode,
    child: child!,
  ),
  home: const MyHomePage(),
);
```

如果 App 已经设置了 builder，请用 `ArgosWidgetInspector` 包裹原 builder
的结果，不要覆盖其中已有的适配层。

启用后会显示“长按检查”开关和完整树入口。开关默认关闭，避免影响业务页面的
长按交互；打开开关后，**直接长按页面中的 Widget** 即可捕获当前位置最深的可布局节点，
高亮其边界并弹出 Key、组件层级、尺寸和诊断属性等详情，不需要先打开节点树或搜索。
点击悬浮 Widget 图标仍可进入完整树，适合查看祖先节点、展开/收起层级、
按类型/Key/诊断属性搜索和手动刷新。所有捕获都只在长按、打开完整树或刷新时发生。

如需在内部调试版本中默认开启长按模式，可以显式配置：

```dart
ArgosWidgetInspector(
  enabled: kDebugMode,
  longPressInitiallyEnabled: true,
  child: child!,
)
```

详情里的“组件层级”使用 Widget 类型面包屑，例如
`… › Column › TextButton › RichText`。快照内部仍使用 `0/0/0/6/0`
这样的数字路径标识节点；其中大量 `0` 来自 Flutter 常见的单子节点包装层，
因此不再把它作为主要界面信息展示。

Argos 使用 Flutter 手势竞争机制处理长按。业务 Widget 如果自己注册并赢得了
长按手势，会继续执行自己的行为；这种情况下可通过悬浮入口查看完整树。

### 实时调参

Flutter Widget 是不可变对象，因此 Argos 不会通过反射强改任意构造参数。
需要调节的区域应显式使用 `ArgosTunable` 注册稳定 ID、属性范围和 builder：

```dart
ArgosTunable(
  id: 'home.title',
  label: '首页标题',
  properties: const <ArgosTuningProperty>[
    ArgosDoubleTuningProperty(
      id: 'fontSize',
      label: '字号',
      initialValue: 20,
      min: 12,
      max: 36,
      divisions: 12,
      decimalPlaces: 0,
    ),
    ArgosColorTuningProperty(
      id: 'textColor',
      label: '字体颜色',
      initialValue: Colors.deepPurple,
    ),
  ],
  builder: (context, values) => Text(
    '可调标题',
    style: TextStyle(
      fontSize: values.doubleValue('fontSize'),
      color: values.colorValue('textColor'),
    ),
  ),
)
```

打开“长按检查”后，长按该区域的任意子 Widget，详情中会出现“实时调参”。
数值属性显示有界滑杆，颜色属性提供内置常用色快选、十六进制输入以及色相、
饱和度、亮度、透明度滑杆，可直接调出任意颜色；修改后 builder 立即重建，
“重置”会恢复该目标的全部初始值。宽高、统一 padding、透明度、字号和圆角都
可以使用有界数值属性表达；字体色和背景色可以注册为两个独立颜色属性。
当目标包含多个颜色属性时，检查器会把它们合并为 Tab，并且只展开当前颜色的
编辑器。也可以通过可选的 `ArgosTuningColorOption` 增加宿主专用快捷色，但
快捷项不会限制自定义颜色。

默认情况下，调参值在 `ArgosWidgetInspector` 的 State 生命周期内保留，
普通父组件重建不会清除。如果需要显式控制生命周期或从代码中调用
`resetTarget` / `resetAll`，可以把自有 controller 传给 Inspector，并由宿主释放：

```dart
final tuningController = ArgosTuningController();

ArgosWidgetInspector(
  enabled: kDebugMode,
  tuningController: tuningController,
  child: child!,
)

// State.dispose:
tuningController.dispose();
```

调参值只存在内存中，不会写入业务存储或生成源码；禁用 Inspector 时
`ArgosTunable` 直接使用声明的初始值且不注册目标。第一版仅支持已注册的
有界数值和任意颜色，不支持回调、业务数据或任意复杂对象。

也可以从自己的入口打开页面。建议在 push 之前捕获，避免把检查器页面自身放进
快照：

```dart
final snapshot = ArgosWidgetSnapshot.captureBindingRoot();
if (snapshot != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ArgosWidgetInspectorPage(
        initialSnapshot: snapshot,
      ),
    ),
  );
}
```

快照默认最多 5,000 个节点、200 层，并且只在已开启模式的长按、打开或点击刷新时重新生成。
Widget diagnostics 可能包含业务文本和配置值，因此请使用 `kDebugMode`
（或内部构建开关）限制入口，不要在生产版本中暴露该功能。

## 诊断会话

Argos 会把网络、原生网络、崩溃、卡顿和资源记录归入同一个有序诊断会话。
默认 `ArgosSessionMode.automatic` 会在 `enableStorage == true` 的首次
`init()` 自动开始录制。如果需要由宿主精确控制复现窗口，可使用手动模式：

```dart
ArgosManager.instance.init(
  config: ArgosConfig(
    sessionMode: ArgosSessionMode.manual,
    enableStorage: true,
    storageAdapter: MyAdapter(),
  ),
  listener: (event) {
    final metadata = event?.eventMetadata;
    debugPrint('${metadata?.sessionId}:${metadata?.sequence}');
  },
);

final session = ArgosManager.instance.startSession(
  label: '复现结算问题',
  attributes: {'build': 'debug'},
);
ArgosManager.instance.pauseSession();
ArgosManager.instance.resumeSession();
await ArgosManager.instance.stopSession();

final sessions = await ArgosManager.instance.getSessions();
final records = await ArgosManager.instance.getSessionRecords(session.id);
```

`captureEnabled` 继续保持源码兼容：设为 `false` 会暂停活动会话，设回
`true` 会恢复同一会话；idle 时设为 `true` 会创建新会话。该门控现在覆盖
所有可持久化事件类型，不再只影响 HTTP。即使 `enableStorage: false` 或没有
adapter，显式开始的会话仍会给事件分配元数据并触发 listener，只是存储查询为空。

`maxSessions` 默认 5；已结束会话按最旧优先整体淘汰，
`maxPacketRecords` / `resourceMaxRecords` 则在活动会话内按事件类型限制。

automatic 默认继续使用兼容的 process 策略：同一进程初始化后保持一个会话，直到
显式停止或进程中断。长时间运行的 App 如果希望把无关诊断窗口自动分开，可以显式
启用 adaptive：

```dart
var cachedContext = ArgosSessionContext(
  fingerprint: 'account-42|tenant-a',
  attributes: {'tenant': 'tenant-a'},
);

ArgosManager.instance.init(
  config: ArgosConfig(
    enableStorage: true,
    storageAdapter: MyAdapter(),
    automaticSessionPolicy: ArgosAutomaticSessionPolicy.adaptive(
      backgroundTimeout: const Duration(minutes: 2),
      maxDuration: const Duration(minutes: 30),
      // 回调应同步且轻量，只返回宿主缓存好的状态。
      contextProvider: () => cachedContext,
    ),
  ),
);
```

adaptive 会在以下时机生成新的 sessionId：App 后台停留达到
`backgroundTimeout` 后回到前台；会话达到 `maxDuration` 后收到下一条事件；
或者上下文 fingerprint 改变后收到下一条事件。短暂后台、路由变化、重复 lifecycle
通知以及显式 pause/resume 都保持原 ID。manual 会话和通过 `startSession()` 显式
创建的会话不会被该策略接管。

fingerprint 仅用于进程内比较，不会自动持久化；只有 `attributes` 会写入 Session，
因此这里只应放脱敏后的诊断标签。`contextProvider` 不应执行 I/O，也不要返回凭据。
将任一 Duration 设为 null 可以关闭对应边界；自动切分的结束原因分别是
`backgroundTimeout`、`maxDuration` 和 `contextChanged`。

## 存储

`ArgosPacketStorage` 通过 `ArgosConfig.storageAdapter` 写入版本化的
session/record 信封，并兼容迁移旧版扁平记录列表。不传 adapter 时持久化是安全
no-op，listener-only 会话仍可工作。`example/` App 提供了一份基于 MMKV 的参考实现。

## 原生抓包

`ArgosNativeCapture.instance.enable()` 会在 iOS 注册 `ArgosURLProtocol`、在 Android 武装 `ArgosOkHttpInterceptor`。原生层抓到的请求通过 `dev.panoptes.argos/native_capture` event channel 推回 Dart，与 Dart 侧抓包合并到同一个存储。

## 配置

```dart
ArgosConfig(
  apmTypes: [
    ArgosCapability.network,
    ArgosCapability.fps,
    ArgosCapability.crash,
    ArgosCapability.jank,
    ArgosCapability.resource,
  ],
  hostWhiteList: ['api.example.com'],
  enableStorage: true,
  sessionMode: ArgosSessionMode.automatic,
  automaticSessionPolicy: const ArgosAutomaticSessionPolicy.process(),
  // 或使用 ArgosAutomaticSessionPolicy.adaptive(...) 显式开启自适应分段
  maxSessions: 5,
  maxPacketRecords: 500,   // 每个非资源类型（网络 / 崩溃 / 卡顿）各自的保留上限
  resourceMaxRecords: 50,  // 资源采样的独立上限——高频采样也不会挤掉已捕获的崩溃或请求
  storagePersistInterval: const Duration(seconds: 5), // 合并落盘周期;
                           // Duration.zero 表示每次写入即落盘(无丢数据窗口)
  proxyProvider: () => kDebugMode ? 'http://127.0.0.1:9091' : null,
  storageAdapter: MyMmkvAdapter(),
  // APM 可选调参：
  jankThresholdMultiplier: 1.0, // 帧 span 超过 帧预算 × 该倍数 即判定掉帧
  resourceSampleInterval: const Duration(seconds: 2),
);
```

各能力独立开关——仅当在 `apmTypes` 中显式列出时才安装对应的 handler/定时器。
不包含 `crash`/`jank`/`resource` 时，`FlutterError.onError`、帧回调与采样均不受影响。
崩溃、卡顿、资源事件与 HTTP 包出现在同一查看器列表中，并以不同图标与标签（崩溃 / 卡顿 / 资源）区分。

运行时开关：

```dart
ArgosManager.instance.captureEnabled = false;
```

## 协议

[MIT](LICENSE) · Copyright (c) 2022-2026 Argos Contributors.
