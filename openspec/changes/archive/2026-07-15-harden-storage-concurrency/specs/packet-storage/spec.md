## ADDED Requirements

### Requirement: 存储操作串行化与顺序一致性
系统 SHALL 将所有变更与读取操作（写入、清空、读取）在单一串行队列上按发起顺序执行，保证全序（total order）。任意两个操作的相对效果 MUST 与它们的发起顺序一致，MUST NOT 因并发交错而产生数据复活、写入丢失或读到中间态。

#### Scenario: 清空撤销先前写入，不被在途写入复活
- **WHEN** 先发起一次记录写入，随后在该写入尚未落盘完成时发起 `clear()`
- **THEN** 最终存储为空：先前写入被清空覆盖，MUST NOT 出现被清空的数据在 `clear()` 之后重新落盘

#### Scenario: 清空后发起的写入正常保留
- **WHEN** 先发起 `clear()`，随后发起一次记录写入
- **THEN** 最终存储包含该新写入的记录，`clear()` 不影响其后发起的写入

#### Scenario: 并发写入不丢更新
- **WHEN** 连续快速发起多次记录写入而不等待各自完成
- **THEN** 全部写入按发起顺序生效，最终存储包含所有未被配额淘汰的记录，MUST NOT 因交错而丢失其中任意一次写入

#### Scenario: 读取观察此前已发起操作的结果
- **WHEN** 发起若干写入后紧接着发起一次读取
- **THEN** 读取返回的列表反映此前已发起的全部写入（与 clear）的结果，而非某次写入提交前的中间态

### Requirement: 合并落盘与强制刷新时机
为避免每次写入都在 UI isolate 上做一次同步整表编码,系统 SHALL 将持久化(编码 + 写回 adapter)与内存变更解耦:写入 SHALL 立即更新内存数据源,持久化 SHALL 按可配置周期 `ArgosConfig.storagePersistInterval` 合并执行;读取 MUST NOT 依赖磁盘落盘完成,始终返回内存中的最新数据。系统 SHALL 在 App 退到后台/暂停时、在 `clear()` 时、以及 `flush()` 被调用时强制立即落盘。

#### Scenario: 读取在落盘之前即反映写入
- **WHEN** 发起一次写入后,在其被持久化落盘之前立即调用 `getAllAsync()`
- **THEN** 返回的列表已包含该次写入的记录(来自内存数据源),不依赖磁盘写入是否完成

#### Scenario: 多次写入合并落盘
- **WHEN** 在一个 `storagePersistInterval` 周期内发生多次写入
- **THEN** 系统对 adapter 的写入次数少于写入次数(合并为更少的落盘),而非每次写入都写一次 adapter

#### Scenario: 退到后台时强制落盘
- **WHEN** App 进入后台/暂停(`AppLifecycleState.paused` 或 `detached`)且存在尚未落盘的写入
- **THEN** 系统立即将当前内存数据落盘,收敛崩溃/被杀导致的丢数据窗口

#### Scenario: 显式 flush 立即落盘
- **WHEN** 调用 `flush()` 且存在尚未落盘的写入
- **THEN** 当前内存数据被立即编码并写回 adapter,返回的 `Future` 在落盘完成后结束

#### Scenario: 零周期退化为每次写入即落盘
- **WHEN** `storagePersistInterval` 配置为 `Duration.zero`
- **THEN** 每次写入后立即落盘,不引入丢数据窗口

## MODIFIED Requirements

### Requirement: 读取所有抓包记录
系统 SHALL 提供接口读取所有已存储的抓包记录，返回按 `startTimestamp` 倒序排列的列表。读取 SHALL 经统一操作队列执行，返回结果反映此前已发起的全部写入与清空操作。

#### Scenario: 有记录时返回列表
- **WHEN** 调用 `ArgosPacketStorage.getAllAsync()`
- **THEN** 返回当前所有记录的列表，按 `startTimestamp` 倒序排列

#### Scenario: 无记录时返回空列表
- **WHEN** 没有任何抓包记录时调用 `ArgosPacketStorage.getAllAsync()`
- **THEN** 返回空列表，不抛出异常

#### Scenario: 读取反映此前写入
- **WHEN** 发起一次写入后紧接着调用 `getAllAsync()`
- **THEN** 返回的列表包含该次写入的记录，不会读到写入提交前的旧状态

### Requirement: 清空所有抓包记录
系统 SHALL 提供接口一次性清空存储的所有抓包记录。清空 SHALL 经统一操作队列执行，与写入操作按发起顺序有序，MUST NOT 绕过写入串行化。

#### Scenario: 清空操作
- **WHEN** 调用 `ArgosPacketStorage.clear()`
- **THEN** 所有抓包记录被删除，随后调用 `getAllAsync()` 返回空列表

#### Scenario: 清空与写入有序
- **WHEN** 在存在在途或排队写入时调用 `clear()`
- **THEN** 清空与这些写入按发起顺序执行，不出现清空被在途写入撤销的情况
