## Why

`kuril_monitor` 的命名仅在内部上下文中有意义，名字本身既不传达功能（性能监控 + 网络抓包），也不具备开源传播力。在准备把项目作为开源 Flutter package 发布到 pub.dev 与 GitHub 之前，需要一次彻底的品牌重塑：选定一个具备隐喻、好记、SEO 干净、可视化资产容易延展的名字。

最终选定 **Argos**——取自希腊神话百眼巨人 Argus Panoptes，"无所不见"的隐喻精确对应"全方位 APM 监控 + HTTP 抓包透视"。名称短（5 字母）、拼写无歧义、pub.dev 与 GitHub Flutter 生态无强占用，可作为命名空间长期持有。

## What Changes

- **包名**：`pubspec.yaml` 的 `name: kuril_monitor` → `name: argos`；同步更新 `description`、`homepage`、新增 `repository` / `issue_tracker`；并修正 `flutter.plugin.platforms` 段——目前是 `flutter create --template=plugin` 留下的 `some_platform` 字面占位，与已存在的 iOS/Android 原生代码脱节，本次同步声明真实的 `pluginClass` 与 Android `package`
- **Dart 公共 API 标识符前缀**：所有 `Kuril*` / `KurilApm*` 类、枚举重命名为 `Argos*`；同时去除冗余的 "Apm" 中缀（`KurilApmConfig` → `ArgosConfig`、`KurilApmManager` → `ArgosManager`、`KurilApmType` → `ArgosCapability`）；含 `KurilNativeCapture` → `ArgosNativeCapture`
- **iOS 原生侧**：`ios/kuril_monitor.podspec` → `ios/argos.podspec`（文件名 MUST 与 pubspec name 一致）；`ios/Classes/Kuril{MonitorPlugin,URLProtocol,EventSink}.swift` → `Argos{Plugin,URLProtocol,EventSink}.swift`（去掉 "Monitor" 中缀）；`@objc(KurilURLProtocol)` 注解、`X-Kuril-Captured` 防重入 header、method/event channel 字面量同步更新
- **Android 原生侧**：Kotlin 包 `tech.echoing.kuril_monitor` → `dev.panoptes.argos`（包目录 git mv）；`Kuril{MonitorPlugin,OkHttpInterceptor}.kt` → `Argos{Plugin,OkHttpInterceptor}.kt`；`build.gradle` group、`AndroidManifest.xml` package、channel 字面量一并更新
- **Method/Event channel 名**：`tech.echoing.kuril_monitor/native_capture[_method]` → `dev.panoptes.argos/native_capture[_method]`，三端（iOS Swift / Android Kotlin / Dart `lib/native/argos_native_capture.dart`）字面量必须同步
- **文件路径**：`lib/` 下所有 `kuril_*.dart` 文件重命名为 `argos_*.dart`，barrel 文件 `lib/kuril_apm.dart` → `lib/argos.dart`
- **导入路径**：所有 `package:kuril_monitor/...` → `package:argos/...`
- **存储 key / mmapID**：`kuril_packet_records` → `argos_packet_records`；MMKV 默认 mmapID（如有用到）从 `"kuril_monitor"` → `"argos"`
- **测试文件**：`test/kuril_*.dart` → `test/argos_*.dart`，同步更新 import 与断言中的类名
- **example 工程**：`example/pubspec.yaml` 的依赖名、`main.dart` / `list_example.dart` 中所有 `kuril_monitor` 引用、`kuril_monitor_example` 包名（如适用）一并更新
- **文档**：README 重写为面向开源用户的英文+中文双语介绍，CHANGELOG 标注 BREAKING（包名/Dart 类名/原生类名/存储 key/channel 名/Android 包路径全部变更），LICENSE 校对（保留 MIT/Apache 等开源许可）
- **BREAKING**: 这是一次破坏性变更——所有依赖 `kuril_monitor` 包名、`Kuril*` 类名、原 channel 名或原 Android 包路径的下游代码必须同步迁移；本次发布将以 `argos@0.1.0` 作为新包的首个版本，不在 pub.dev 上发布同名续作

## Capabilities

### New Capabilities
<!-- 无新功能能力。本次仅是命名重塑，不改变运行时行为或外部可观察语义。 -->

### Modified Capabilities

所有现有 capability 的 spec 中均出现了 `Kuril*` / `kuril_*` 字样，本次变更需要同步更新这些 spec 中的标识符引用，使 spec 与重命名后的实现保持一致。功能语义不变，仅替换标识符：

- `curl-builder`：`KurilCurlBuilder` → `ArgosCurlBuilder`
- `dynamic-proxy-provider`：`KurilApmConfig` → `ArgosConfig`、`KurilApmManager` → `ArgosManager`、`KurilHttpMonitor` → `ArgosHttpMonitor`
- `http-capture-pipeline`：`KurilHttp*` → `ArgosHttp*`、`KurilApm*` → `Argos*`、`KurilPacketRecord` → `ArgosPacketRecord`
- `packet-record-ui`：`KurilPacket{List,Detail}Page` → `ArgosPacket{List,Detail}Page`、`KurilApmManager` → `ArgosManager`、`KurilPacketStorage` → `ArgosPacketStorage`
- `packet-route-grouping`：`KurilPacketListPage` → `ArgosPacketListPage`
- `packet-storage`：`KurilApmConfig` → `ArgosConfig`、`KurilPacketStorage` → `ArgosPacketStorage`、`KurilPacketRecord` → `ArgosPacketRecord`、存储 key `kuril_packet_records` → `argos_packet_records`
- `packet-visual-polish`：`KurilPacketDetailPage` → `ArgosPacketDetailPage`

## Impact

- **Dart 代码**：`lib/` 下全部 16 个 `.dart` 文件路径与内容都需要更新（含 `lib/native/kuril_native_capture.dart`）；`test/` 下 3 个测试文件；`example/` 下 dart 源、pubspec、平台模板（iOS bundle id / Android applicationId 不需改动，但 example 包名建议同步为 `argos_example`）。
- **iOS 原生**：1 个 podspec + 3 个 Swift 文件全部重命名；`@objc(KurilURLProtocol)` 注解必须同步改为 `@objc(ArgosURLProtocol)`，否则 `NSClassFromString` 路径解析会失败（参考最近 commit `60746da` 的修复经验）；method/event channel 字面量更新。无新增 Pod 依赖。
- **Android 原生**：Kotlin 包目录 `tech/echoing/kuril_monitor/` 整体 git mv 到 `tech/echoing/argos/`；2 个 Kotlin 文件重命名 + 内容更新；`build.gradle` group 与 `AndroidManifest.xml` package 同步；method/event channel 字面量更新。无新增 Gradle 依赖。
- **API 兼容**：彻底破坏。下游以 `import 'package:kuril_monitor/...'` 引用本插件的代码必须改 import + 类名；接入 `MethodChannel('tech.echoing.kuril_monitor/...')` 的代码（如有外部嵌入）必须改 channel 名。**不提供 deprecated typedef 兼容层**——v0.x 阶段没有公开发布，重命名直接发生。
- **存储兼容**：本地已存在的 `kuril_packet_records` MMKV key 会被新版本忽略（视为空数据）；旧 JSON 文件清理逻辑也需改名。开发者本地的历史抓包记录会丢失，开源 v0.1.0 不承诺此前内部版本的数据迁移。
- **构建/原生**：iOS Pod 名称随 podspec 文件名变更（`kuril_monitor` → `argos`），宿主 App `Podfile.lock` 会重新解析；Android Gradle module 名同步从 `kuril_monitor` 变为 `argos`，`settings.gradle` 与 `app/build.gradle` 中 `implementation project(':kuril_monitor')`（如有）需对应更新。
- **CI / 发布**：发布到 pub.dev 前需要在 pub.dev 上保留 `argos` 包名（dry-run 校验）；GitHub 仓库 rename 与 default branch、homepage 链接同步。
