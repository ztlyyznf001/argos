## Context

`ArgosPacketStorage` 把所有记录序列化为一条 JSON 列表，存于 MMKV 的单个 key 下。写入路径（`_writeAsync`，`lib/storage/argos_packet_storage.dart:38`）在追加后执行淘汰：

```dart
records.add(record.toJson());
while (records.length > maxRecords) {
  records.removeAt(0);       // 删最旧的一条，不看 kind
}
```

三处调用（`argos_http_monitor.dart`、`argos_manager.dart` 的 `dispatch`、`native/argos_native_capture.dart`）都传入 `maxRecords: config.maxPacketRecords ?? 200`。资源监控经 `dispatch()` 每 2 秒写一条，与崩溃、网络记录共用这条列表和这一个上限。因此淘汰是「全局最旧优先」，资源采样一多就把崩溃顶掉。

`ArgosPacketRecord` 自带 `kind` 字段（`network`/`crash`/`jank`/`resource`），存储层已经能区分类型，只是淘汰时没用上。

## Goals / Non-Goals

**Goals:**
- 一条既有的崩溃或网络记录，永远不会因为资源采样的写入而被淘汰。
- 各类型各自持有独立的保留上限，某类型超限只淘汰该类型自己最旧的记录。
- 向后兼容：未配置新字段时行为合理，既有 `maxPacketRecords` 对非资源类型语义不变。

**Non-Goals:**
- 不降低资源采样频率（仍每 2s 采样并落盘）——写放大是另一个问题，留待后续。
- 不改动数据模型、展示层或监控采集逻辑。
- 不改变存储介质（仍是 MMKV 单 key + JSON 列表）。
- 不引入按时间的过期淘汰（TTL）；本次只做按条数的分区淘汰。

## Decisions

### 决策一：按 `kind` 分区淘汰，而非「资源单独一桶、其余共享一桶」

两种分区都能让资源不再挤掉崩溃：

- **两桶**：资源一个上限，`network+crash+jank` 共享 `maxPacketRecords` 一个上限。改动更小，但一串网络请求仍可能顶掉崩溃。
- **按 kind 独立上限**（选定）：每个 `kind` 各有上限，`crash` 拿到自己的一整份配额，几乎不可能被任何其他类型顶掉。

崩溃是最稀有、也最不该丢的记录，给它独立配额与 proposal 的动机最契合，且实现代价与两桶几乎相同（都要按 kind 计数），故选按 kind 独立上限。

### 决策二：只新增一个配置字段 `resourceMaxRecords`，其余类型沿用 `maxPacketRecords`

配额解析规则：`kind == 'resource'` → `resourceMaxRecords`（默认 50）；其余所有 kind → `maxPacketRecords`（默认 200）。

- 资源默认 50：2s 一采样也有约 100 秒的滚动窗口，足够在 Inspector 里看内存趋势，又不会侵占其他类型。
- 曾考虑用 `Map<ArgosCapability,int>` 让每类都可单独配，但除资源外没有哪类会高频自动落盘，四个可配上限属于过度设计。单字段 + 复用 `maxPacketRecords` 是够用的最小面。

**语义变化需明确**：`maxPacketRecords` 从「所有记录的总上限」变为「每个非资源类型各自的上限」。对只抓网络的既有用户无影响（网络仍最多 `maxPacketRecords` 条）；但启用多类型时，最坏情况总存储量约为 `3 * maxPacketRecords + resourceMaxRecords`。对一个调试期的 Inspector 而言可接受，并在 proposal 的 Impact 与本文档中写明。

### 决策三：单次写入只需淘汰「本次写入的那个 kind」

一次 `append` 只加入一条某 `kind` 的记录，只有该 `kind` 的计数可能因此超限，其余 kind 不受影响。故淘汰逻辑从「扫描整条列表删最旧」收窄为「只删该 kind 最旧的、直到其计数不超过该 kind 的上限」：

```
records.add(newRecord);            // 追加到末尾（末尾 = 最新）
final cap = capFor(newRecord.kind);
// 从头（最旧）扫描，删除该 kind 多出的最旧记录
var overflow = countOfKind(records, newRecord.kind) - cap;
records.removeWhere((r) => r.kind == newRecord.kind && overflow-- > 0);
```

保持存储列表的插入顺序（末尾最新），`getAllAsync` 仍按 `startTimestamp` 倒序返回，混合时间线不受影响。复杂度 O(n)，n 为当前存储条数（数百级），与原实现同量级。

### 决策四：配额经参数下传，存储层不反向依赖 `ArgosManager`

延续现状：`append`/`appendRecord` 已接收 `maxRecords`，本次并列新增 `resourceMaxRecords` 参数，由三处调用点从 `config` 取值传入。存储层保持对配置无反向依赖，便于单测（可直接构造 storage + 内存 adapter 传入任意上限）。

## Risks / Trade-offs

- **[总存储量上升（最坏约 3×maxPacketRecords + resourceMaxRecords）]** → 目标是调试期 Inspector，JSON+MMKV 数百条记录的体量可接受；在 proposal 与本文档显式记录语义变化，不让它悄悄发生。
- **[`maxPacketRecords` 语义从「总量」变为「每非资源类型」，可能与既有用户预期不符]** → 对最常见的「只抓网络」场景零影响；在 README/配置注释与 spec 场景中说明新语义。
- **[资源默认 50 条可能对个别排查场景偏少]** → 提供 `resourceMaxRecords` 让用户按需调大；50 只是默认值不是硬上限。
- **[按 kind 淘汰仍不解决 2s 落盘的写放大]** → 明确划为 Non-Goal，proposal 中指向后续可能的「降低资源落盘频率」变更；本次不承诺。
- **[分区淘汰逻辑改动写入热路径]** → 以单元测试覆盖：资源写满不动崩溃、各 kind 独立触顶、只淘汰本 kind、混合时间线顺序不变、自定义上限生效。
