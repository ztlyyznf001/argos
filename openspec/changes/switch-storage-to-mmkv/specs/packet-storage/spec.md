## ADDED Requirements

### Requirement: MMKV 初始化失败时安全降级
系统 SHALL 在 MMKV 原生 SDK 初始化失败（如宿主 App 锁定了不兼容版本的 MMKV Pod）时捕获异常并切换到"禁用存储"状态，使得所有写入操作成为 no-op、读取操作返回空列表，并 MUST NOT 让异常扩散到上层调用方。

#### Scenario: MMKV 初始化抛出异常时不 crash
- **WHEN** `ArgosPacketStorage` 首次使用时 `MMKV.defaultMMKV()`（或等价初始化调用）抛出异常
- **THEN** 系统捕获异常，将内部状态置为禁用，后续 `append` 调用不写入任何内容，`getAllAsync()` 返回空列表，`clear()` 不抛异常

#### Scenario: 初始化失败时仅告警一次
- **WHEN** MMKV 初始化失败并切换到禁用状态
- **THEN** 系统通过 `debugPrint` 输出一次性告警说明原因，后续相同调用不再重复输出

### Requirement: iOS 原生 Pod 版本协调指引
插件 SHALL 通过 `example/ios/Podfile` 与 README 向宿主 App 提供 MMKV 原生 Pod 版本统一的 `post_install` 示例与排查指引，避免 `MMKVConfigDefault()` 等符号在旧版 Pod 下缺失导致的构建失败；由于插件自身不含原生 iOS 代码，MMKV 的依赖声明由 `mmkv` Flutter 插件承载，插件仓库不再维护单独的 podspec。

#### Scenario: example 工程提供 post_install 示例
- **WHEN** 打开 `example/ios/Podfile`
- **THEN** 文件的 `post_install` 钩子中包含一段针对 MMKV 的版本协调/诊断逻辑（或明确的注释示例），供宿主 App 参考

#### Scenario: README 提供冲突排查章节
- **WHEN** 打开仓库根目录的 `README.md`
- **THEN** 其中包含一节说明：如何在宿主 App 的 Podfile 中协调 MMKV 版本，以及在冲突无法解决时如何通过 `ArgosConfig.enableStorage = false` 兜底

## MODIFIED Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应）序列化为 JSON 并通过 MMKV 持久化到本地；存储使用独立的 `mmapID`（例如 `"argos"`）以避免与宿主 App 自身的 MMKV 根命名空间冲突。

#### Scenario: 请求完成后自动写入
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `ArgosConfig.enableStorage` 为 `true`
- **THEN** 系统将该次请求的快照数据追加写入 MMKV 实例（独立 mmapID），写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向 MMKV 写入任何抓包数据，已有记录不受影响

#### Scenario: MMKV 初始化失败时视同存储关闭
- **WHEN** `enableStorage` 为 `true` 但 MMKV 初始化失败（见"MMKV 初始化失败时安全降级"要求）
- **THEN** 系统行为等价于 `enableStorage = false`，写入 no-op 且不向上抛出异常
