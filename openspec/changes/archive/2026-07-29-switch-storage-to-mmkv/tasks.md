## 1. 依赖与原生集成

- [x] 1.1 在 `pubspec.yaml` 中加入 `mmkv: ^2.0.0`（与 `example/pubspec.yaml` 对齐，实际解析为 2.4.0），保留 `path_provider` 用于清理旧 JSON 文件
- [x] 1.2 执行 `flutter pub get`，`pubspec.lock` 更新完成
- [x] 1.3 在 `example/ios/Podfile` 的 `post_install` 钩子中加入 MMKV 版本协调示例（供宿主 App 参考）
- [x] 1.4 在 `example/ios` 运行 `pod install`，确认无 Pod 冲突

## 2. 存储实现重写

- [x] 2.1 重写 `lib/storage/argos_packet_storage.dart`，以独立 `mmapID = "argos"` 获取 MMKV 实例
- [x] 2.2 在单个 key `argos_packet_records` 下存储整个记录列表的 JSON 字符串，与现有序列化格式对齐
- [x] 2.3 实现惰性初始化：首次使用时 `await MMKV.initialize()` 后 `MMKV(mmapID)`，捕获异常并切换 `_disabled = true`
- [x] 2.4 实现降级路径：`_disabled` 为 true 时 `append` no-op、`getAllAsync` 返回空列表、`clear` no-op，首次降级时 `debugPrint` 一次性告警
- [x] 2.5 保持 `append` / `getAllAsync` / `clear` 的公共签名与语义不变，让上层调用方无需修改
- [x] 2.6 保留 `maxPacketRecords` 淘汰逻辑：写入前读取→追加→按条数裁剪→回写
- [x] 2.7 首次初始化成功后异步尝试删除旧的 `argos_packet_records.json` 文件（如果存在），忽略删除失败

## 3. 上层适配与清理

- [x] 3.1 检查 `lib/apm/argos_http_monitor.dart` 中存储相关调用，确认无需修改
- [x] 3.2 检查 `lib/ui/argos_packet_list_page.dart` 的读取路径，确认兼容新实现
- [x] 3.3 保留 `path_provider` 与 `dart:io` 用于 2.7 的旧文件清理（故不完全移除）

## 4. 验证

- [x] 4.1 `flutter analyze` 通过（仅两条与本次改动无关的 overridden_fields info）
- [ ] 4.2 运行现有单元测试/组件测试：`argos_http_info_model_test.dart` 与 `argos_packet_detail_page_test.dart` 通过；`argos_test.dart` 有**预先存在**的失败（`.instance` 在 `ensureInitialized()` 之前被读取，与本次变更无关）
- [ ] 4.3 `flutter build apk` 构建 Android 侧成功（建议由用户在本地或 CI 执行，耗时较长）
- [ ] 4.4 `cd example && flutter build ios --no-codesign` 构建 iOS 侧成功（建议由用户在本地执行）
- [ ] 4.5 手动端到端：启动 example → 触发若干 HTTP 请求 → kill 进程 → 重启 → 验证 `argos_packet_list_page` 中记录已恢复
- [ ] 4.6 手动 `clear()`：调用清空后重启，列表为空
- [ ] 4.7 模拟降级：临时 mock 初始化抛异常，验证上层 UI 不崩且列表为空

## 5. 文档

- [x] 5.1 README 更新：存储机制改回 MMKV，补充宿主 App 的 Podfile 集成指引与 `enableStorage` 兜底说明
- [x] 5.2 CHANGELOG 更新：在 Unreleased 段标注 BREAKING（历史 JSON 文件记录不会自动迁移）

## 6. 归档

- [ ] 6.1 实现全部完成后运行 `openspec archive switch-storage-to-mmkv` 完成变更归档
