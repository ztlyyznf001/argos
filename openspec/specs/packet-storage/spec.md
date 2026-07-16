# packet-storage Specification

## Purpose

定义抓包记录的本地持久化行为：`ArgosPacketRecord` 的落盘与读取、最大记录条数上限与旧记录淘汰、大 Body 截断、错误请求的存储，以及记录中路由名称字段的写入与运行时更新。

## Requirements

### Requirement: 抓包数据持久化存储
系统 SHALL 将完整的 HTTP 抓包记录（请求与响应，含路由名称）序列化为 JSON 并通过 MMKV 持久化到本地。

#### Scenario: 请求完成后自动写入（含路由名称）
- **WHEN** 一次 HTTP 请求的响应数据被完整接收（`recordResponse` 触发）且 `ArgosConfig.enableStorage` 为 `true`
- **THEN** 系统将该次请求的快照数据（含 `routeName` 字段）追加写入 MMKV，写入后可通过读取接口取回

#### Scenario: 存储默认关闭
- **WHEN** 用户未配置 `enableStorage` 或将其设为 `false`
- **THEN** 系统不向 MMKV 写入任何抓包数据，已有记录不受影响

### Requirement: 最大记录条数限制
系统 SHALL 按 `ArgosPacketRecord.kind` 分区限制存储的记录条数：每个类型各自持有独立的保留上限，某类型写入超限时，仅淘汰**该类型**时间最早的记录，MUST NOT 因某一类型的写入而淘汰其他类型的记录。配额解析规则为：`kind == 'resource'` 使用 `ArgosConfig.resourceMaxRecords`（默认 50），其余所有类型使用 `ArgosConfig.maxPacketRecords`（默认 200）。

#### Scenario: 某类型超限时只淘汰该类型最旧记录
- **WHEN** 某一类型（如 `resource`）新记录写入后，该类型的记录条数超过其配额
- **THEN** 系统删除**该类型**中时间最早的记录，直到该类型条数不超过其配额，其他类型的记录不受影响

#### Scenario: 资源采样不淘汰崩溃与网络记录
- **WHEN** 存储中已有崩溃与网络记录，随后持续写入大量资源采样记录直至资源类型触及其上限
- **THEN** 先前的崩溃与网络记录仍然保留，不因资源采样的写入而被淘汰

#### Scenario: 各类型独立触顶互不影响
- **WHEN** 网络记录已达 `maxPacketRecords`，此时写入一条崩溃记录
- **THEN** 该崩溃记录正常写入，不会因为网络记录已满而被拒绝或触发网络记录之外的淘汰；崩溃类型按其自身配额独立淘汰

#### Scenario: 自定义资源配额
- **WHEN** 用户在 `ArgosConfig` 中设置 `resourceMaxRecords` 为自定义值（如 20）
- **THEN** 系统以该值作为资源类型的保留上限进行淘汰

#### Scenario: 自定义非资源配额
- **WHEN** 用户在 `ArgosConfig` 中设置 `maxPacketRecords` 为自定义值（如 50）
- **THEN** 系统以该值作为每个非资源类型（网络/崩溃/卡顿）各自的保留上限

#### Scenario: 向后兼容默认值
- **WHEN** 用户未设置 `resourceMaxRecords`
- **THEN** 资源类型使用默认上限 50，非资源类型使用 `maxPacketRecords`（默认 200），启用存储的既有行为对只抓网络的场景保持不变

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

### Requirement: 大 Body 截断
系统 SHALL 对超过 100KB 的请求体进行截断，只存储前 100KB 并在截断处附加截断标注；对于文本响应体，系统 SHALL 完整存储捕获到的响应内容，不因 100KB 阈值截断；对于非文本响应体，系统 SHALL 不存储 body 内容，仅保留元数据。

#### Scenario: 请求体超过 100KB
- **WHEN** 请求体字节数超过 100 * 1024 字节
- **THEN** 系统只存储前 100KB 内容，并在末尾追加字符串 `"[TRUNCATED]"`

#### Scenario: 文本响应体超过 100KB
- **WHEN** 响应 Content-Type 为文本类型，且响应体字节数超过 100 * 1024 字节
- **THEN** 系统完整存储响应体内容，不附加 `"[TRUNCATED]"`

#### Scenario: 非文本响应体
- **WHEN** 响应 Content-Type 为 `image/*`、`application/octet-stream` 或其他非文本类型
- **THEN** 系统不存储响应体文本内容，`responseBody` 为空字符串，`responseCode`、`responseHeaders` 和 `responseSize` 正常记录

### Requirement: 错误请求也持久化存储
系统 SHALL 在 HTTP 请求失败时（`ArgosHttpInfo.error != null`）将错误快照持久化到 MMKV，与正常请求记录共享同一存储和淘汰机制。错误记录属于 `network` 类型，参与 `network` 类型的配额淘汰。

#### Scenario: 错误记录写入 MMKV
- **WHEN** 一次 HTTP 请求因网络异常失败，且 `enableStorage` 为 `true`，且 host 在白名单中
- **THEN** MMKV 中增加一条记录，其中 `responseCode = 0`，`responseBody = ''`，`error` 字段包含错误描述

#### Scenario: 错误记录参与 network 类型的配额淘汰
- **WHEN** 错误记录写入后，`network` 类型的记录条数超过 `maxPacketRecords`
- **THEN** 系统淘汰 `network` 类型中时间最早的记录（无论正常还是错误），直到该类型条数不超过上限；其他类型的记录不受影响

### Requirement: ArgosPacketRecord 包含路由名称字段
`ArgosPacketRecord` SHALL 包含 `routeName` 字段（`String`，默认空字符串），记录请求响应完成时宿主 App 当前所在的页面路由名称。

#### Scenario: routeName 随记录持久化
- **WHEN** 一条抓包记录被写入 MMKV
- **THEN** 该记录的 JSON 中包含 `routeName` 键，值为写入时 `ArgosManager.instance.currentRoute` 的快照

#### Scenario: 反序列化旧记录时 routeName 降级为空字符串
- **WHEN** 从 MMKV 读取一条不含 `routeName` 键的旧格式记录
- **THEN** `ArgosPacketRecord.routeName` 为空字符串，不抛出异常

### Requirement: currentRoute 运行时可更新
`ArgosManager` SHALL 提供可写属性 `currentRoute`（`String`），宿主 App 在路由变更时主动赋值，`_dispatchHttpInfo` 写入快照时读取该值注入 `routeName`。

#### Scenario: 宿主更新 currentRoute 后的请求携带新路由
- **WHEN** 宿主将 `ArgosManager.instance.currentRoute` 设为 `"/detail"` 后发起一次 HTTP 请求
- **THEN** 该请求完成后存储的记录 `routeName` 为 `"/detail"`

#### Scenario: currentRoute 初始值为空字符串
- **WHEN** 宿主未设置 `currentRoute` 就有请求完成
- **THEN** 该记录的 `routeName` 为空字符串

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
