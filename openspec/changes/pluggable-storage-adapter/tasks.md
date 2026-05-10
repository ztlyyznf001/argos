## 1. 新增 ArgosStorageAdapter 抽象接口

- [x] 1.1 新建 `lib/storage/argos_storage_adapter.dart`，定义抽象类 `ArgosStorageAdapter`，声明 `Future<String?> read()`、`Future<void> write(String value)`、`Future<void> clear()` 三个方法
- [x] 1.2 在 `lib/argos.dart` 中 export `argos_storage_adapter.dart`

## 2. 更新 ArgosConfig

- [x] 2.1 在 `lib/config/argos_config.dart` 中新增字段 `final ArgosStorageAdapter? storageAdapter`
- [x] 2.2 更新构造函数，添加可选参数 `this.storageAdapter`

## 3. 重写 ArgosPacketStorage

- [x] 3.1 移除 `lib/storage/argos_packet_storage.dart` 中所有 MMKV 相关代码（import、字段、`_getMMKV`、`_initialize`、`_removeLegacyFile`、`_readListFrom(MMKV)` 等）
- [x] 3.2 新增字段 `ArgosStorageAdapter? _adapter`，并新增 `void setAdapter(ArgosStorageAdapter? adapter)` 方法
- [x] 3.3 重写 `_writeAsync`：通过 `_adapter?.read()` 读取现有 JSON，追加新记录后调用 `_adapter?.write(jsonEncode(records))`；adapter 为 null 时直接返回
- [x] 3.4 重写 `getAllAsync`：通过 `_adapter?.read()` 读取 JSON，解析后排序返回；adapter 为 null 返回空列表
- [x] 3.5 重写 `clear`：调用 `_adapter?.clear()`；adapter 为 null 时直接返回

## 4. 连接 ArgosManager

- [x] 4.1 在 `lib/argos_manager.dart` 的 `initializeMonitors` 中，`ArgosCapability.network` case 初始化后调用 `ArgosPacketStorage.instance.setAdapter(config?.storageAdapter)`

## 5. 移除包依赖

- [x] 5.1 从 `pubspec.yaml` 中删除 `mmkv` 依赖
- [x] 5.2 从 `pubspec.yaml` 中删除 `path_provider` 依赖（仅 argos_packet_storage 使用）
- [x] 5.3 运行 `dart pub get` 确认依赖解析正常

## 6. 验证

- [x] 6.1 运行 `dart analyze` 确认无编译错误
