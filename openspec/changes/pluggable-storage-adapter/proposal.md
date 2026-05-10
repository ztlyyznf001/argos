## Why

`argos` 当前硬依赖 `mmkv` 包做持久化，宿主 App 若不使用 MMKV 或不希望引入额外原生依赖，就无法使用该库的存储功能。将存储后端抽象为可注入的接口后，宿主可自行选择实现（MMKV、SharedPreferences、内存等），同时消除包级别的原生依赖。

## What Changes

- 新增抽象类 `ArgosStorageAdapter`，声明 `write`、`readAll`、`clear` 三个方法接口
- `ArgosConfig` 新增可选字段 `storageAdapter: ArgosStorageAdapter?`，由宿主注入实现
- `ArgosPacketStorage` 不再直接依赖 MMKV，改为委托给注入的 `storageAdapter`；未注入时存储静默禁用
- **BREAKING**: 移除 `pubspec.yaml` 中的 `mmkv` 和 `path_provider` 直接依赖（迁移至宿主层）
- `ArgosManager.init` 将 `config.storageAdapter` 传递给 `ArgosPacketStorage`

## Capabilities

### New Capabilities

- `storage-adapter`: 可插拔存储适配器接口，宿主实现后注入，解耦 argos 与具体存储引擎

### Modified Capabilities

- `packet-storage`: 存储后端从硬编码 MMKV 改为委托给外部注入的 `ArgosStorageAdapter`，所有行为语义（追加、读取、清空、条数限制）保持不变，仅实现层变化

## Impact

- **`lib/storage/argos_packet_storage.dart`**: 移除 MMKV 逻辑，改为调用 `ArgosStorageAdapter`
- **`lib/config/argos_config.dart`**: 新增 `storageAdapter` 字段
- **`lib/argos_manager.dart`**: init 时将 adapter 注入 `ArgosPacketStorage`
- **`pubspec.yaml`**: 移除 `mmkv`、`path_provider` 依赖
- **Public API breaking**: 宿主需自行提供存储实现并注入，不再开箱即用 MMKV 持久化
