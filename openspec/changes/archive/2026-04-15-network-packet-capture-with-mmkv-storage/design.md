## Context

`kuril_monitor` 是一个 Flutter 插件，通过 `HttpOverrides` + 自定义 `HttpClient` 拦截所有 HTTP 流量。当前拦截结果只通过 `KurilApmManager.listener` 回调透传，没有持久化层和可视化 UI。

需要新增两个能力：
1. **MMKV 持久化存储**：将抓到的 `KurilHttpInfo` 序列化并写入 MMKV。
2. **抓包记录 UI**：Flutter Widget，展示历史记录列表和单条详情。

项目为 Flutter plugin，核心 lib 不应依赖 Flutter Widget（纯 Dart），但 UI 部分可以依赖 Flutter。

## Goals / Non-Goals

**Goals:**
- 将抓包数据持久化到 MMKV，支持读取、追加、清空操作
- 限制最大存储条数，超出时淘汰最旧记录（FIFO）
- 提供列表页 Widget（`KurilPacketListPage`）和详情页 Widget（`KurilPacketDetailPage`）
- 默认关闭存储，通过 `KurilApmConfig.enableStorage` 开启
- 对现有使用方无任何 breaking change

**Non-Goals:**
- 不实现网络代理/中间人抓包（当前已有代理能力，不扩展）
- 不实现请求 Body 的流式/分段存储（超大 Body 截断存储）
- 不实现跨设备同步或云端上报
- UI 不做复杂筛选/搜索（保持 MVP）

## Decisions

### 1. 存储方案：MMKV（`package:mmkv`）

**决策**：使用 MMKV 而非 sqflite / shared_preferences。

**理由**：
- 写入性能高，适合高频抓包场景
- 用户已明确指定
- Key-Value 模型对列表存储使用 JSON 数组即可，无需复杂 schema

**替代方案考虑**：sqflite 更适合结构化查询，但对于简单的列表 + 详情场景过于重量级。

**存储结构**：
- Key: `kuril_packet_records` → Value: JSON 数组，每项是一条 `KurilHttpInfo` 的序列化快照
- Key: `kuril_packet_records_count` → 可选计数缓存

### 2. 序列化：手写 `toJson` / `fromJson`

**决策**：在 `KurilHttpInfo`（及相关 model）上手写 JSON 序列化，不引入代码生成（build_runner）。

**理由**：字段数量有限，手写清晰可控，避免引入 build_runner 增加复杂度。

**数据快照结构**（存储时）：
```json
{
  "id": "<uuid or timestamp>",
  "uri": "https://...",
  "method": "POST",
  "startTimestamp": 1713000000000,
  "endTimestamp": 1713000000250,
  "requestHeaders": { ... },
  "requestBody": "...",
  "responseCode": 200,
  "responseBody": "...",
  "responseHeaders": { ... },
  "responseSize": 1024
}
```

### 3. 存储触发点：`KurilHttpClientRequest.recordResponse`

**决策**：在 `recordResponse` 方法调用完成后，若存储开关开启，则调用存储层写入。

**理由**：此处是请求/响应均完整的最早时机，复用已有钩子点，不需要新增拦截逻辑。

### 4. UI 模块独立目录

**决策**：UI 代码放在 `lib/ui/`，存储代码放在 `lib/storage/`，通过 `lib/kuril_apm.dart` 统一导出。

**理由**：职责分离，便于按需引用。

### 5. 最大记录条数：默认 200 条

超出时删除最旧的一条（list shift），保证存储不会无限增长。可通过 `KurilApmConfig.maxPacketRecords` 配置。

## Risks / Trade-offs

- **大 Body 性能风险**：响应 Body 可能很大（MB 级），全量存入 MMKV 会影响性能。
  → Mitigation：截断存储，Body 超过 100KB 时只保存前 100KB 并标注截断。
- **MMKV 初始化依赖**：MMKV 需要在 Native 层初始化（`MMKV.initializeMMKV()`），需在 example 中说明调用时机。
  → Mitigation：在 README / example 中加说明，存储类做 lazy init 保护。
- **JSON 序列化 HttpHeaders**：`dart:io` 的 `HttpHeaders` 没有 `toJson`，需手动遍历 header 字段。
  → Mitigation：写辅助函数 `headersToMap(HttpHeaders)` 提取常用字段。

## Open Questions

- MMKV 在 plugin 的 `pubspec.yaml` 中添加依赖是否会影响宿主工程的 MMKV 版本？（需测试，若冲突可考虑将存储层提取到 example 或由外部注入）
