## ADDED Requirements

### Requirement: ArgosStorageAdapter 抽象接口
系统 SHALL 提供抽象类 `ArgosStorageAdapter`，声明三个异步方法：`Future<String?> read()`、`Future<void> write(String value)`、`Future<void> clear()`。宿主 App MUST 实现该抽象类以提供存储后端。

#### Scenario: 宿主实现并注入 adapter
- **WHEN** 宿主创建一个继承 `ArgosStorageAdapter` 的实现类并通过 `ArgosConfig(storageAdapter: myAdapter)` 注入
- **THEN** `ArgosPacketStorage` 所有 I/O 操作均委托给该实现，不调用任何内置存储引擎

#### Scenario: adapter 未注入时存储静默禁用
- **WHEN** `storageAdapter` 为 `null`（宿主未注入）
- **THEN** 所有 `append` 调用静默跳过，`getAllAsync` 返回空列表，`clear` 无操作，不抛出异常

### Requirement: 通过 ArgosConfig 注入 storageAdapter
`ArgosConfig` SHALL 新增可选字段 `storageAdapter: ArgosStorageAdapter?`，允许宿主在初始化阶段声明存储实现。

#### Scenario: 初始化时配置 storageAdapter
- **WHEN** 调用 `ArgosManager.instance.init(config: ArgosConfig(storageAdapter: myAdapter, enableStorage: true))`
- **THEN** `ArgosPacketStorage` 使用该 adapter 进行所有后续读写操作
