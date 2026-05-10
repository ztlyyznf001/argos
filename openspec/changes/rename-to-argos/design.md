## Context

`kuril_monitor` 是一个内部孵化的 Flutter APM + HTTP 抓包插件，当前已具备 FPS 监控、HTTP 全链路捕获、curl 复刻、记录列表/详情 UI、按路由分组、可插拔存储适配器等能力。原名 `kuril` 来自最初团队代号，对外开源缺乏隐喻、辨识度与传播力。

为登陆 pub.dev / GitHub 开源，需要一次彻底的 brand rename。本设计文档界定改名的边界、命名映射表、迁移策略与发布前置条件，避免后续在补丁中反复修订标识符。

## Goals / Non-Goals

**Goals:**

- 包名、所有公共 API 类名、文件名、import 路径、存储 key 与 mmapID 全部从 `kuril*` 切换到 `argos*`，一次性完成
- 顺手清理冗余命名：去掉过时的 "Apm" 中缀，让 API 表层更口语化（`ArgosManager.instance`、`ArgosConfig(...)` 比 `KurilApmManager.instance` / `KurilApmConfig(...)` 更接近现代 Flutter package 风格）
- spec 与实现保持一致：所有 capability 的 spec 文档同步更新标识符引用
- 让仓库具备开源就绪状态：pubspec metadata 完整、README 双语、LICENSE 明确、CHANGELOG 显式标注 BREAKING

**Non-Goals:**

- 不更改任何运行时行为、能力边界、UI 视觉、存储格式（除 key 名）。本次纯命名变更，不夹带功能改动
- 不提供 deprecated typedef / barrel re-export 兼容层。v0.x 阶段没有公开下游，无需为兼容性付出复杂度
- 不引入新的目录结构（如 `lib/src/` 私有化）。改名 + 路径替换即可，结构性重构由后续 change 单独提案
- 不为 example 工程添加新功能或重构布局
- 不处理仓库 GitHub rename / pub.dev 发布的具体 ops 流程（这些由发布 checklist 而非代码变更承担，但 tasks.md 会留出占位项）

## Decisions

### D1: 命名映射表（权威）

所有 `Kuril*` 标识符按下表 1:1 重命名。"Apm" 中缀在重命名时一并去除，因为 "APM" 缩写在面向开发者的 API 表层不直观，且 `Argos` 本身已经承担"监控"语义，无需冗余前缀。

| 原标识符 | 新标识符 | 说明 |
| --- | --- | --- |
| 包名 `kuril_monitor` | `argos` | pubspec.yaml `name` |
| `KurilApmManager` | `ArgosManager` | 单例入口 |
| `KurilApmConfig` | `ArgosConfig` | 配置对象 |
| `KurilApmType` | `ArgosCapability` | 枚举（更直观地表达"启用哪些能力"） |
| `KurilBaseMonitor` | `ArgosBaseMonitor` | 内部抽象基类 |
| `KurilBaseAmpModel` | `ArgosBaseModel` | 同时修正历史拼写 "Amp" → 正确含义 |
| `KurilFpsMonitor` | `ArgosFpsMonitor` | |
| `KurilFpsInfo` | `ArgosFpsInfo` | |
| `KurilFpsRecorder` | `ArgosFpsRecorder` | |
| `KurilHttpMonitor` | `ArgosHttpMonitor` | |
| `KurilHttpInfo` | `ArgosHttpInfo` | |
| `KurilHttpClient` | `ArgosHttpClient` | |
| `KurilHttpClientRequest` | `ArgosHttpClientRequest` | |
| `KurilHttpClientResponse` | `ArgosHttpClientResponse` | |
| `KurilHttpOverrides` | `ArgosHttpOverrides` | |
| `KurilCurlBuilder` | `ArgosCurlBuilder` | |
| `KurilPacketStorage` | `ArgosPacketStorage` | |
| `KurilPacketRecord` | `ArgosPacketRecord` | |
| `KurilStorageAdapter` | `ArgosStorageAdapter` | |
| `KurilPacketListPage` | `ArgosPacketListPage` | |
| `KurilPacketDetailPage` | `ArgosPacketDetailPage` | |
| `KurilNativeCapture` | `ArgosNativeCapture` | Dart 侧原生通道封装 |
| 存储 key `kuril_packet_records` | `argos_packet_records` | 顶层 storage key |
| 默认 mmapID `"kuril_monitor"` | `"argos"` | 当宿主使用 MMKV adapter 时 |
| 旧 JSON 兜底文件名 `kuril_packet_records.json` | `argos_packet_records.json` | 仅在迁移路径上引用 |
| iOS Swift 类 `KurilMonitorPlugin` | `ArgosPlugin` | FlutterPlugin 入口；同步去掉 "Monitor" 中缀以匹配 Dart 侧 |
| iOS Swift 类 `KurilURLProtocol` | `ArgosURLProtocol` | `@objc(...)` 注解同步更新，保证 `NSClassFromString` 仍可解析 |
| iOS Swift 类 `KurilEventSink` | `ArgosEventSink` | |
| iOS Podspec 文件 `ios/kuril_monitor.podspec` | `ios/argos.podspec` | 文件名 MUST 与 pubspec `name` 一致 |
| iOS Podspec `s.name = 'kuril_monitor'` | `s.name = 'argos'` | summary / description / homepage 同步更新 |
| iOS 捕获 marker header `X-Kuril-Captured` | `X-Argos-Captured` | URLProtocol 防重入标记 |
| Android Kotlin 类 `KurilMonitorPlugin` | `ArgosPlugin` | |
| Android Kotlin 类 `KurilOkHttpInterceptor` | `ArgosOkHttpInterceptor` | |
| Android 包 `tech.echoing.kuril_monitor` | `dev.panoptes.argos` | 包路径与目录结构同步 git mv：`android/src/main/kotlin/tech/echoing/kuril_monitor/` → `.../dev/panoptes/argos/` |
| Android `build.gradle` `group 'tech.echoing.kuril_monitor'` | `group 'dev.panoptes.argos'` | |
| Android `AndroidManifest.xml` `package="tech.echoing.kuril_monitor"` | `package="dev.panoptes.argos"` | |
| Method channel `tech.echoing.kuril_monitor/native_capture_method` | `dev.panoptes.argos/native_capture_method` | iOS Swift / Android Kotlin / Dart 三处常量必须同步 |
| Event channel `tech.echoing.kuril_monitor/native_capture` | `dev.panoptes.argos/native_capture` | 同上 |
| iOS Podspec `s.author = { 'Echo' => 'mobile@echo.tech' }` | `{ 'Argos Contributors' => 'noreply@panoptes.dev' }` | 占位邮箱；用户拥有域名后可改 |
| iOS Podspec `s.homepage = 'https://g.echo.tech/mobile/flutter-monitor'` | `'https://github.com/ztlyyznf001/argos'` | 与 pubspec.homepage 一致 |
| LICENSE Copyright `回响科技` | `Argos Contributors` | MIT 保留；年份保留 2022 + 追加 2026 |

文件路径同步：`lib/<dir>/kuril_<name>.dart` → `lib/<dir>/argos_<name>.dart`；barrel 入口 `lib/kuril_apm.dart` → `lib/argos.dart`（去掉 apm 后缀，与包名一致便于 `import 'package:argos/argos.dart';`）。原生文件路径与类名一一对应：`ios/Classes/Kuril<Name>.swift` → `ios/Classes/Argos<Name>.swift`、`android/src/main/kotlin/tech/echoing/kuril_monitor/Kuril<Name>.kt` → `android/src/main/kotlin/tech/echoing/argos/Argos<Name>.kt`。

### D2: 不提供向后兼容层

- **选择**：直接删除旧标识符，不留 `typedef KurilApmConfig = ArgosConfig;` 之类的兼容 alias，也不在 `lib/argos.dart` 之外保留旧 barrel
- **理由**：v0.x 阶段没有公开发布，下游消费者只有团队内部 echo App，迁移成本可控；保留兼容层会污染新包的 API 表面，带来"两套名字都能用"的长期债务
- **替代**：保留 6 个月的 deprecated typedef → 放弃，因为没有外部用户值得为之付出表面积代价

### D3: 不迁移本地历史 MMKV 数据

- **选择**：v0.1.0 启动时，旧 key `kuril_packet_records` 的内容直接被忽略；不写一次性读旧 key 写新 key 的迁移逻辑
- **理由**：抓包数据是诊断性短生命周期数据，没人会因为升级到 `argos` 而期待找回上周的请求记录；迁移代码会在 v0.1.x 后的每次发布都成为死代码
- **替代**：写一段一次性迁移并在 v0.2 删除 → 引入复杂度且只服务团队内部一次升级

### D4: example 工程同步重命名为 `argos_example`

- **选择**：`example/pubspec.yaml` 中 `name: kuril_monitor_example` → `name: argos_example`，同时更新 `dependencies.kuril_monitor` → `dependencies.argos: { path: ../ }`
- **理由**：example 是开源用户进入仓库后第一眼看到的工程，命名不一致会立刻削弱品牌一致性；同步成本极低
- **替代**：保留 example 包名 → 不一致感强，放弃

### D5: 修正 pubspec.yaml 的 plugin 配置以匹配真实原生代码

- **选择**：本仓库已含完整原生抓包能力（iOS NSURLProtocol + Android OkHttp Interceptor），但 `pubspec.yaml` 的 `flutter.plugin.platforms` 段仍是 `flutter create --template=plugin` 留下的字面占位（`some_platform: { pluginClass: somePluginClass }`），与现实脱节。借本次改名同步把它修正为真实的 plugin 元数据：
  ```yaml
  flutter:
    plugin:
      platforms:
        ios:
          pluginClass: ArgosPlugin
        android:
          package: tech.echoing.argos
          pluginClass: ArgosPlugin
  ```
- **理由**：占位元数据会让 `flutter pub publish --dry-run` 报错或让宿主 App 在 plugin 注册期找不到入口；而且原生代码确实存在，配置必须真实反映
- **替代**：保持占位、把真实元数据补充推到下一个 PR → 与原生 rename 强相关，分两次反而更乱

### D8: 原生侧"去 Monitor 后缀"与 Dart 侧保持一致

- **选择**：Dart 侧已把 `KurilApmManager` 简化为 `ArgosManager`、barrel 命名为 `argos.dart`；原生侧的 `KurilMonitorPlugin` 也同步简化为 `ArgosPlugin`（不是 `ArgosMonitorPlugin`）
- **理由**：插件类是宿主 App 集成时唯一可见的"门面"标识，命名应与包名一致，不引入"Monitor"语义重复
- **替代**：保留 `ArgosMonitorPlugin` → 与 Dart 侧风格不一致，且 "Argos" 已隐含监控含义，不需要额外修饰

### D9: Android 包名为 `dev.panoptes.argos`

- **选择**：`tech.echoing.kuril_monitor` → `dev.panoptes.argos`。组织前缀同步从 `tech.echoing`（旧团队代号）切换到 `dev.panoptes`，与 Argos 品牌的神话语义打通——Panoptes 是 Argus Panoptes 的"全见"称号，与项目名 Argos 同源
- **理由**：
  1. 组织段和项目段在神话上呼应（"Panoptes 旗下的 Argos"），讲品牌故事时是连贯的
  2. `dev.panoptes` 在 Flutter / pub.dev / Maven 生态没有撞名，命名空间干净
  3. `dev.panoptes.*` 留出后续工具（如 `argos-cli`、`argos-web`）的扩展位
- **替代**：
  - `dev.argos` → 项目和组织合一，缺少分层；未来同系列工具会撞名
  - `io.github.zhaotianli.argos` → 零成本但与个人 GitHub 账号绑定，仓库转移即破坏
  - 保留 `tech.echoing.argos` → 与新品牌脱节，违背改名初衷

### D6: README 双语 + 开源就绪元数据

- **选择**：README 重写为：英文 README（pub.dev 与国际开发者友好）+ 链接到 `README_zh.md`；首屏含 logo 占位、安装指引、最小代码示例、特性 bullet、License、Contributing 链接
- **理由**：开源默认主语言为英文，但保留中文版本以服务现有团队和中文社区
- **替代**：纯中文 README → 限制开源传播；纯英文 → 现有团队上下文丢失

### D7: 不在本次提案中执行 GitHub repo rename / pub.dev 发布

- **选择**：tasks.md 标注"代码侧改名完成"为本 change 的 done 边界；GitHub 仓库改名（`flutter-monitor` → `argos`）和 pub.dev 首发由发布 checklist 处理，不阻塞代码合入
- **理由**：仓库改名涉及外部链接与现有 PR/Issue 的副作用，应作为单独的 ops 决定；pub.dev 发布需要 owner 权限与 `flutter pub publish --dry-run` 的人工核对
- **替代**：在 tasks.md 中包含 `gh repo rename` 与 `flutter pub publish` 步骤 → 把代码 PR 与发布动作耦合，回滚困难

## Risks / Trade-offs

- **风险**：宿主 echo App 同时合入了对 `KurilApmConfig` 等的引用，若 PR 排序错位会造成短暂构建中断 → **缓解**：发布前与宿主仓库 owner 协同，PR 配对合入；改名 PR 描述中给出宿主侧 sed 命令模板
- **风险**：搜索/替换不彻底，遗留某些 `Kuril` 字符串（如注释、debugPrint 中的字串、错误消息） → **缓解**：tasks.md 明确要求 `rg "Kuril\\|kuril" --type dart --type yaml --type md` 全量验证为空
- **风险**：测试文件改名后，CI 缓存仍指向旧路径 → **缓解**：本仓库 CI 不缓存测试路径；本地清 `.dart_tool/` 即可
- **权衡**：放弃兼容 typedef → 换取干净的 API 表面与单次迁移；已在 D2 评估并接受

## Migration Plan

1. **Dart 侧批量重命名（机械步骤，可脚本化）**：
   - `git mv` 全部 `lib/**/kuril_*.dart` 与 `test/kuril_*.dart` 到 `argos_*.dart`；barrel `lib/kuril_apm.dart` → `lib/argos.dart`；`lib/native/kuril_native_capture.dart` → `lib/native/argos_native_capture.dart`
   - 全仓 `rg --files-with-matches "Kuril\|kuril"` + `sd` 或 `perl -pi -e` 按 D1 表逐项替换。建议分两轮：先类名（区分大小写：`Kuril` → `Argos`、`kuril_apm` → `argos`、`kuril_monitor` → `argos`、`kuril_` → `argos_`），再特殊字串（`KurilApmManager` 已在第一轮被替换为 `ArgosApmManager`，第二轮再 `ArgosApm` → `Argos` 去掉 Apm 中缀）
2. **手工核对**：`KurilBaseAmpModel` → `ArgosBaseModel` 的 "Amp" 拼写需要单独处理；`KurilApmType` → `ArgosCapability` 是语义重命名，需要单独 sed
3. **iOS 侧重命名**：
   - `git mv ios/kuril_monitor.podspec ios/argos.podspec`，编辑 `s.name`、`s.summary`、`s.description`、`s.homepage`
   - `git mv ios/Classes/KurilMonitorPlugin.swift ios/Classes/ArgosPlugin.swift`、`ios/Classes/KurilURLProtocol.swift` → `ArgosURLProtocol.swift`、`ios/Classes/KurilEventSink.swift` → `ArgosEventSink.swift`
   - 文件内部全量替换：类名、`@objc(KurilURLProtocol)` → `@objc(ArgosURLProtocol)`、channel name 字面量、`X-Kuril-Captured` → `X-Argos-Captured`、`KurilEventSink.shared` → `ArgosEventSink.shared`
4. **Android 侧重命名**：
   - `git mv android/src/main/kotlin/tech/echoing/kuril_monitor android/src/main/kotlin/tech/echoing/argos`（整个目录）
   - 子文件 `git mv KurilMonitorPlugin.kt ArgosPlugin.kt`、`KurilOkHttpInterceptor.kt` → `ArgosOkHttpInterceptor.kt`
   - 内容替换：`package tech.echoing.kuril_monitor` → `package tech.echoing.argos`，类名，channel name 字面量，`KurilMonitorPlugin.eventSink` → `ArgosPlugin.eventSink`
   - `android/build.gradle`：`group 'tech.echoing.kuril_monitor'` → `group 'tech.echoing.argos'`
   - `android/src/main/AndroidManifest.xml`：`package="tech.echoing.kuril_monitor"` → `package="tech.echoing.argos"`
5. **pubspec.yaml**：替换 `name`、`description`、`homepage`，新增 `repository`、`issue_tracker`，**修正**（不是删除）`flutter.plugin.platforms` 段：iOS 声明 `pluginClass: ArgosPlugin`，Android 声明 `package: tech.echoing.argos` + `pluginClass: ArgosPlugin`
6. **example/pubspec.yaml**：`name: argos_example`、`dependencies.argos: { path: ../ }`
5. **CHANGELOG.md**：在 Unreleased 段加入 `### Breaking Changes` 子段，列出包名/类名/storage key 三类破坏性变更
6. **README**：重写为开源就绪版本（英文为主，链接中文版）
7. **构建验证**：
   - `flutter pub get`（根目录与 example 各一次）
   - `flutter analyze`（应通过，仅原有的 overridden_fields 类 info）
   - `cd example/ios && pod install`（确认 podspec 重命名后无错误，宿主能找到 `argos` pod）
   - `cd example && flutter build ios --no-codesign` 与 `flutter build apk`（双端构建通过，确认 plugin 类被正确注册）
   - `cd example && flutter run`（人工确认 list/detail 页可正常加载、搜索/过滤/清空功能可用、原生抓包仍工作——iOS 侧验证 NSURLProtocol 截获、Android 侧验证 OkHttp 拦截器写入记录）
8. **全量字符串审计**：`rg "Kuril\\|kuril\\|kuril_monitor" -t dart -t yaml -t md -t swift -t kotlin -t gradle`（应当只剩下 `openspec/changes/archive/**` 历史归档与本次 change 文档自身——这些不应改动）

**回滚**：本次为机械重命名，无新逻辑。回滚等价于 `git revert`；本地数据丢失（旧 mmkv key）不可恢复，但抓包数据可重新生成。

## Open Questions

- **License 选型**：当前 LICENSE 是什么？开源默认建议 Apache-2.0（Flutter 生态主流，含专利授权），需在实施前 Read 一次现有 LICENSE 决定保留/替换
- **pub.dev 包名占位**：实施前需 `flutter pub deps` 或 pub.dev 网页确认 `argos` 在 Dart 生态可用；若已被占用，备选 `argos_flutter` 或 `argos_monitor`
- **logo / brand 资产**：README 是否需要 SVG logo 占位？倾向：留 `<!-- TODO: logo -->` 占位，由后续 change 提交资产
- **`ArgosCapability` 命名是否过度发挥**：D1 把 `KurilApmType` 改为 `ArgosCapability`。若团队倾向最小变更，可保留 `ArgosApmType`；待 propose review 时确认
- **Android 包前缀 `tech.echoing` 是否保留**：D9 默认保留组织前缀。若开源后想脱钩组织域名（改为 `dev.argos` / `io.argos`），需要确认目标域名归属并在实施前更新 D9 与所有 Android 字面量。倾向：本次保留 `tech.echoing.argos`，域名脱钩留作后续单独 change
- **iOS plugin 类名是否包含 `Plugin` 后缀**：D8 选 `ArgosPlugin`（与 Flutter 官方插件惯例一致，如 `PathProviderPlugin`）。如果想更激进地省略后缀（直接 `Argos`），会和 Dart 侧 `Argos` 命名空间冲突——保留 `ArgosPlugin` 是当前最优解
