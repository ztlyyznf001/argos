## Why

抓包持久化能力的 spec 一直声明由 MMKV 承担，但由于宿主 App 锁定了旧版 MMKV 原生 Pod，导致 `MMKVConfigDefault()` 在 iOS 构建时不可用，代码侧（commit `c38ea8a`）临时降级为 `path_provider` + JSON 文件。这是实现与 spec 的偏离，同时丢失了 MMKV 提供的高频写入性能、单键读写和进程崩溃保护等特性。我们希望把存储实现切回 MMKV，同时彻底解决 iOS 构建冲突问题，恢复 spec 与实现的一致。

## What Changes

- 将 `ArgosPacketStorage` 的底层存储从 JSON 文件（`path_provider`）切换回 MMKV
- 为 iOS 构建冲突给出可落地的解决方案：锁定插件侧 MMKV pod 版本范围，或在宿主 App Podfile 中声明版本约束；若宿主仍锁定旧版 Pod，提供显式降级/禁用路径
- 在 `pubspec.yaml` 中重新引入 MMKV 依赖，移除或保留 `path_provider` 作为 fallback（由 design 决定）
- 保持 `ArgosPacketStorage` 公共 API（`append`、`getAllAsync`、`clear`）不变，上层调用方无需修改
- **BREAKING**: 历史写入的 JSON 文件记录不会自动迁移到 MMKV（由 design 决定是否提供一次性迁移）

## Capabilities

### New Capabilities
<!-- 无新能力，本次仅调整现有能力的实现并补充跨平台集成要求 -->

### Modified Capabilities
- `packet-storage`: 新增对 iOS 原生 Pod 版本冲突的显式处理要求；允许在 MMKV 初始化失败时以安全方式降级（不写入但不 crash）

## Impact

- 代码：`lib/storage/argos_packet_storage.dart`（重写底层实现）、`lib/apm/argos_http_monitor.dart`（若初始化方式变化）、`pubspec.yaml`（依赖切换）
- 原生：iOS Podfile 的 MMKV 版本协调；Android 侧通常无冲突，但需确认 `mmkv` Flutter 插件的 Android 嵌入
- 测试：`example/` 工程的 iOS 构建验证；单元测试若 mock 了文件存储，需调整
- 文档：README 中关于存储机制的说明需同步更新
