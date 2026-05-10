## 1. 依赖与配置

- [x] 1.1 在 `pubspec.yaml` 中添加 `mmkv` 依赖（plugin 本体）
- [x] 1.2 在 `KurilApmConfig` 中新增 `enableStorage` 字段（bool，默认 false）
- [x] 1.3 在 `KurilApmConfig` 中新增 `maxPacketRecords` 字段（int，默认 200）

## 2. 数据模型序列化

- [x] 2.1 在 `KurilHttpInfo` 上新增 `toJson()` 方法，生成存储快照 JSON（包含 id、uri、method、startTimestamp、endTimestamp、requestHeaders、requestBody、responseCode、responseBody、responseHeaders、responseSize）
- [x] 2.2 新增 `KurilHttpInfo.fromJson(Map)` 工厂构造函数，用于从存储中反序列化
- [x] 2.3 新增辅助函数 `headersToMap(HttpHeaders?)` 将 `dart:io HttpHeaders` 转为 `Map<String, String>`
- [x] 2.4 实现 Body 截断逻辑：超过 100KB 时截断并追加 `[TRUNCATED]`

## 3. 存储层（`lib/storage/`）

- [x] 3.1 创建 `lib/storage/kuril_packet_storage.dart`，封装 MMKV 读写操作
- [x] 3.2 实现 `KurilPacketStorage.append(KurilHttpInfo)` 方法：读取当前列表 → 追加 → 超出上限则 FIFO 淘汰 → 写回 MMKV
- [x] 3.3 实现 `KurilPacketStorage.getAll()` 方法：从 MMKV 读取 JSON 数组并反序列化，按 `startTimestamp` 倒序返回
- [x] 3.4 实现 `KurilPacketStorage.clear()` 方法：清空 MMKV 中的抓包记录 Key

## 4. 存储触发集成

- [x] 4.1 在 `KurilHttpClientRequest.recordResponse` 中，判断 `KurilApmManager.instance.config?.enableStorage == true` 时调用 `KurilPacketStorage.append(httpInfo)`
- [x] 4.2 在 `lib/kuril_apm.dart` 中导出 `KurilPacketStorage`

## 5. UI 层（`lib/ui/`）

- [x] 5.1 创建 `lib/ui/kuril_packet_list_page.dart`：列表页 Widget，`initState` / `didChangeDependencies` 从存储加载数据
- [x] 5.2 实现列表 Item：展示 Method、URL（缩略）、状态码、耗时（ms）、请求时间
- [x] 5.3 实现空状态 UI："暂无抓包记录"
- [x] 5.4 实现"清空"按钮 + 确认弹窗，点击确认后调用 `KurilPacketStorage.clear()` 并刷新列表
- [x] 5.5 创建 `lib/ui/kuril_packet_detail_page.dart`：详情页 Widget，接收 `KurilHttpInfo` 作为参数
- [x] 5.6 详情页实现请求信息区域：完整 URL、Method、请求头、请求体
- [x] 5.7 详情页实现响应信息区域：状态码、响应头、响应体（JSON 自动格式化）、大小、耗时
- [x] 5.8 实现 `KurilCurlBuilder.build(KurilHttpInfo) → String`：将记录转换为 cURL 命令字符串（`-X`、`-H`、`--data-raw`）
- [x] 5.9 详情页添加"复制 cURL"按钮，点击后调用 `KurilCurlBuilder.build`，写入剪贴板（`Clipboard.setData`），显示 SnackBar 提示"已复制 cURL"
- [x] 5.10 在 `lib/kuril_apm.dart` 中导出 `KurilPacketListPage`、`KurilPacketDetailPage` 和 `KurilCurlBuilder`

## 6. Example 集成验证

- [x] 6.1 在 `example/pubspec.yaml` 中确认 MMKV 依赖正确引入，添加 `MMKV.initializeMMKV()` 初始化调用
- [x] 6.2 在 `example/lib/main.dart` 中开启 `enableStorage: true` 并配置 `KurilApmType.network`
- [x] 6.3 在 example 中添加入口按钮，跳转到 `KurilPacketListPage`，验证列表展示与详情跳转功能正常
