## 1. 准备工作

- [ ] 1.1 在 pub.dev 网页确认 `argos` 包名可用；若被占用则与提案者确认备选（`argos_flutter` / `argos_monitor`），并同步更新 design.md D1
- [x] 1.2 阅读现有 `LICENSE`，确认是否需要替换为开源标准 License（建议 Apache-2.0；如已是合适 License 则保留）
- [ ] 1.3 确认宿主 echo App 改名 PR 的合入窗口，与本 PR 配对发布以避免短暂构建中断

## 2. 包名与 pubspec

- [x] 2.1 修改 `pubspec.yaml`：`name: kuril_monitor` → `name: argos`，更新 `description` 为面向开源用户的简介，`homepage` 指向新 GitHub URL（占位即可），新增 `repository` 与 `issue_tracker`
- [x] 2.2 修正 `pubspec.yaml` 中 `flutter.plugin.platforms` 段（当前是 `some_platform: { pluginClass: somePluginClass }` 占位字面），改为：
      ```yaml
      flutter:
        plugin:
          platforms:
            ios:
              pluginClass: ArgosPlugin
            android:
              package: dev.panoptes.argos
              pluginClass: ArgosPlugin
      ```
- [x] 2.3 修改 `example/pubspec.yaml`：`name: kuril_monitor_example` → `name: argos_example`，依赖项 `kuril_monitor: { path: ../ }` → `argos: { path: ../ }`

## 3. Dart 文件路径重命名

- [x] 3.1 `git mv lib/kuril_apm.dart lib/argos.dart`
- [x] 3.2 `git mv lib/kuril_apm_manager.dart lib/argos_manager.dart`
- [x] 3.3 `git mv lib/kuril_apm_recorder.dart lib/argos_recorder.dart`
- [x] 3.4 `git mv lib/apm/kuril_base_monitor.dart lib/apm/argos_base_monitor.dart`
- [x] 3.5 `git mv lib/apm/kuril_fps_monitor.dart lib/apm/argos_fps_monitor.dart`
- [x] 3.6 `git mv lib/apm/kuril_http_monitor.dart lib/apm/argos_http_monitor.dart`
- [x] 3.7 `git mv lib/config/kuril_apm_config.dart lib/config/argos_config.dart`
- [x] 3.8 `git mv lib/model/kuril_apm_model.dart lib/model/argos_model.dart`
- [x] 3.9 `git mv lib/model/kuril_fps_info_model.dart lib/model/argos_fps_info_model.dart`
- [x] 3.10 `git mv lib/model/kuril_http_info_model.dart lib/model/argos_http_info_model.dart`
- [x] 3.11 `git mv lib/native/kuril_native_capture.dart lib/native/argos_native_capture.dart`
- [x] 3.12 `git mv lib/storage/kuril_packet_storage.dart lib/storage/argos_packet_storage.dart`
- [x] 3.13 `git mv lib/storage/kuril_storage_adapter.dart lib/storage/argos_storage_adapter.dart`
- [x] 3.14 `git mv lib/ui/kuril_curl_builder.dart lib/ui/argos_curl_builder.dart`
- [x] 3.15 `git mv lib/ui/kuril_packet_detail_page.dart lib/ui/argos_packet_detail_page.dart`
- [x] 3.16 `git mv lib/ui/kuril_packet_list_page.dart lib/ui/argos_packet_list_page.dart`
- [x] 3.17 `git mv test/kuril_http_info_model_test.dart test/argos_http_info_model_test.dart`
- [x] 3.18 `git mv test/kuril_monitor_test.dart test/argos_test.dart`
- [x] 3.19 `git mv test/kuril_packet_detail_page_test.dart test/argos_packet_detail_page_test.dart`

## 3a. iOS 原生重命名

- [x] 3a.1 `git mv ios/kuril_monitor.podspec ios/argos.podspec`
- [x] 3a.2 `git mv ios/Classes/KurilMonitorPlugin.swift ios/Classes/ArgosPlugin.swift`
- [x] 3a.3 `git mv ios/Classes/KurilURLProtocol.swift ios/Classes/ArgosURLProtocol.swift`
- [x] 3a.4 `git mv ios/Classes/KurilEventSink.swift ios/Classes/ArgosEventSink.swift`
- [x] 3a.5 编辑 `ios/argos.podspec`：`s.name`、`s.summary`、`s.description`、`s.homepage` 全部更新；保留 `s.platform = :ios, '12.0'` 与 swift_version 不变
- [x] 3a.6 在 Swift 内容中替换：类名（`KurilMonitorPlugin` → `ArgosPlugin`、`KurilURLProtocol` → `ArgosURLProtocol`、`KurilEventSink` → `ArgosEventSink`）、`@objc(KurilURLProtocol)` → `@objc(ArgosURLProtocol)`、`X-Kuril-Captured` → `X-Argos-Captured`
- [x] 3a.7 在 Swift 内容中替换 channel 字面量：`tech.echoing.kuril_monitor/native_capture_method` → `dev.panoptes.argos/native_capture_method`、`tech.echoing.kuril_monitor/native_capture` → `dev.panoptes.argos/native_capture`

## 3b. Android 原生重命名

- [x] 3b.1 `git mv android/src/main/kotlin/tech/echoing/kuril_monitor android/src/main/kotlin/tech/echoing/argos`（整目录）
- [x] 3b.2 `git mv android/src/main/kotlin/tech/echoing/argos/KurilMonitorPlugin.kt android/src/main/kotlin/tech/echoing/argos/ArgosPlugin.kt`
- [x] 3b.3 `git mv android/src/main/kotlin/tech/echoing/argos/KurilOkHttpInterceptor.kt android/src/main/kotlin/tech/echoing/argos/ArgosOkHttpInterceptor.kt`
- [x] 3b.4 在 Kotlin 内容中替换：`package tech.echoing.kuril_monitor` → `package dev.panoptes.argos`；类名（`KurilMonitorPlugin` → `ArgosPlugin`、`KurilOkHttpInterceptor` → `ArgosOkHttpInterceptor`）；`KurilMonitorPlugin.eventSink` 引用 → `ArgosPlugin.eventSink`
- [x] 3b.5 在 Kotlin 内容中替换 channel 字面量：与 3a.7 同步
- [x] 3b.6 编辑 `android/build.gradle`：`group 'tech.echoing.kuril_monitor'` → `group 'dev.panoptes.argos'`
- [x] 3b.7 编辑 `android/src/main/AndroidManifest.xml`：`package="tech.echoing.kuril_monitor"` → `package="dev.panoptes.argos"`

## 4. 标识符与字符串批量替换

按照 design.md D1 命名映射表，对仓库内所有 `.dart` / `.yaml` / `.md` / `.lock` / `.swift` / `.kt` / `.gradle` / `AndroidManifest.xml` / `.podspec` 文件做批量替换。建议分轮，避免单次 sed 引入歧义：

- [x] 4.1 第一轮（包名 + 路径前缀 + Dart class）：`package:kuril_monitor` → `package:argos`、`kuril_monitor_example` → `argos_example`、`KurilNativeCapture` → `ArgosNativeCapture`、`KurilHttpClientResponse` → `ArgosHttpClientResponse`、`KurilHttpClientRequest` → `ArgosHttpClientRequest`、`KurilHttpClient` → `ArgosHttpClient`、`KurilHttpOverrides` → `ArgosHttpOverrides`、`KurilHttpMonitor` → `ArgosHttpMonitor`、`KurilHttpInfo` → `ArgosHttpInfo`、`KurilFpsMonitor` → `ArgosFpsMonitor`、`KurilFpsInfo` → `ArgosFpsInfo`、`KurilFpsRecorder` → `ArgosFpsRecorder`、`KurilCurlBuilder` → `ArgosCurlBuilder`、`KurilPacketStorage` → `ArgosPacketStorage`、`KurilPacketRecord` → `ArgosPacketRecord`、`KurilPacketListPage` → `ArgosPacketListPage`、`KurilPacketDetailPage` → `ArgosPacketDetailPage`、`KurilStorageAdapter` → `ArgosStorageAdapter`、`KurilBaseMonitor` → `ArgosBaseMonitor`
- [x] 4.2 第二轮（语义重命名 + 拼写修正）：`KurilApmManager` → `ArgosManager`、`KurilApmConfig` → `ArgosConfig`、`KurilApmType` → `ArgosCapability`、`KurilBaseAmpModel` → `ArgosBaseModel`
- [x] 4.3 第三轮（原生类名——这一轮 sed 应只作用于 ios/ 与 android/ 目录）：`KurilMonitorPlugin` → `ArgosPlugin`、`KurilURLProtocol` → `ArgosURLProtocol`、`KurilEventSink` → `ArgosEventSink`、`KurilOkHttpInterceptor` → `ArgosOkHttpInterceptor`
- [x] 4.4 第四轮（包路径与 channel 字面量）：`tech.echoing.kuril_monitor/native_capture` → `dev.panoptes.argos/native_capture`（method 与 event channel 各一处后缀，建议直接全字符串替换 `tech.echoing.kuril_monitor` → `dev.panoptes.argos`）；Android Kotlin `package` 声明同步
- [x] 4.5 第五轮（存储 key / mmapID / header 字符串字面量）：`'kuril_packet_records'` → `'argos_packet_records'`、`"kuril_monitor"`（mmapID 用法处）→ `"argos"`、旧 JSON 兜底文件名 `kuril_packet_records.json` → `argos_packet_records.json`、iOS `X-Kuril-Captured` → `X-Argos-Captured`
- [x] 4.6 全量审计：`rg "Kuril\|kuril" -t dart -t yaml -t md -t swift -t kotlin -t gradle` + `rg "kuril_monitor" --type-add 'plist:*.plist' -t plist` 应只剩下 `openspec/changes/archive/**` 与本次 change 文档自身（`openspec/changes/rename-to-argos/`）；任何其他位置的命中都需手动核对

## 5. README / CHANGELOG / LICENSE

- [x] 5.1 重写 `README.md` 为开源就绪版本（英文为主），包含：项目一句话介绍 + 隐喻、特性 bullet（FPS、HTTP capture、curl 复刻、按路由分组、可插拔存储、运行时开关）、安装代码块（`flutter pub add argos`）、最小使用示例、Storage Adapter 说明、Contributing & License 链接
- [x] 5.2 新增 `README_zh.md`：保留现有中文内容并迁移更新，README.md 顶部链接到中文版
- [x] 5.3 在 `CHANGELOG.md` 顶部新增 `## 0.1.0` 段，列出 Breaking Changes（包名 `kuril_monitor` → `argos`、所有 `Kuril*` 类名 → `Argos*` 含 `KurilApm*` 去掉 Apm 前缀、存储 key/mmapID 重命名、不迁移历史本地数据），并归档 Unreleased
- [x] 5.4 校对 `LICENSE` 文件：若内容是 placeholder 或非开源 License，替换为 Apache-2.0；保留版权人 / 年份正确

## 6. 验证

- [x] 6.1 在仓库根目录运行 `flutter pub get`，确认无依赖解析错误
- [x] 6.2 在 `example/` 目录运行 `flutter pub get`
- [ ] 6.3 `cd example/ios && pod install`，确认 podspec 重命名后 CocoaPods 能解析新的 `argos` pod 名（`Pods/Manifest.lock` 应包含 `argos`，不再有 `kuril_monitor`）
- [x] 6.4 运行 `flutter analyze`，确认无新增 error/warning（已有的 overridden_fields info 可忽略）
- [ ] 6.5 运行 `flutter test`，所有测试通过（保留对原本预先存在失败的测试的处理结论：若原 `kuril_monitor_test.dart` 存在已知失败，可在改名同时把对应的测试断言更新到新 API；若失败原因与改名无关，留 TODO 注释）
- [ ] 6.6 `cd example && flutter build ios --no-codesign` 与 `flutter build apk`，双端构建通过
- [ ] 6.7 `cd example && flutter run`（iOS 真机或模拟器 + Android 各一次），人工验证：列表页加载、详情页渲染、搜索/过滤、清空操作、抓包开关切换、按路由分组——全部行为与改名前一致
- [ ] 6.8 原生抓包烟雾测试：在 example 中触发若干 `URLSession`（iOS）或 `OkHttpClient`（Android）非 Dart `HttpClient` 路径的请求，确认 `ArgosURLProtocol` / `ArgosOkHttpInterceptor` 仍能拦截并通过 `dev.panoptes.argos/native_capture` event channel 把记录推送到 Dart 侧
- [ ] 6.9 `flutter pub publish --dry-run`（在仓库根目录），输出应无 ERROR；常见警告（如 example 目录、未填写 description）若存在，记录到后续 housekeeping change

## 7. spec 同步

- [x] 7.1 实施完成后运行 OpenSpec 归档流程，将 `openspec/changes/rename-to-argos/specs/*/spec.md` 中的 MODIFIED Requirements 合并回 `openspec/specs/<capability>/spec.md`，使主 spec 与重命名后的实现保持一致
- [x] 7.2 若实施过程中发现新的 `Kuril*` 字串泄漏到任何 spec 中（如脚本未覆盖到的注释），追加补充提交并同步更新 spec

## 8. 归档

- [ ] 8.1 全部任务完成、宿主侧改名 PR 已合入后，将 `openspec/changes/rename-to-argos/` 移动到 `openspec/changes/archive/2026-MM-DD-rename-to-argos/`（实施日期）
