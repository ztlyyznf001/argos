## Why

Argos 已能采集网络、崩溃、卡顿和资源事件，但这些记录只是共享一个全局滚动列表，缺少一次诊断过程的明确边界、稳定顺序和可恢复状态，因而无法可靠回答“这次问题复现期间发生了什么”。同时，`captureEnabled` 目前只完整约束 HTTP/原生抓包，其他 APM 事件仍可能继续回调和落盘，阻碍所有事件形成一致的诊断会话。

## What Changes

- 引入 `ArgosDiagnosticSession` 及会话状态机，支持自动/手动启动、暂停、恢复、显式结束，以及 App 重启后将未正常结束的会话恢复为 `interrupted`。
- 为持久化事件增加可空 `sessionId`、会话内单调 `sequence` 和可靠的唯一事件 ID；不含新字段的旧记录继续作为未归属历史记录读取。
- 将网络、原生网络、崩溃、卡顿和资源事件统一送入 `ArgosManager.dispatch`，由同一录制开关决定是否进入 listener 和存储，再在写入时绑定活动会话。
- 保留 `captureEnabled` 作为兼容入口：关闭映射为暂停当前会话，重新开启映射为恢复；没有可恢复会话时创建新会话。
- 将持久化格式升级为带 `schemaVersion` 的会话/事件信封，并兼容读取既有 JSON 列表格式；会话元数据与事件继续通过可插拔 `ArgosStorageAdapter` 串行写入。
- 引入会话级保留策略：优先整体淘汰最旧的已结束会话，活动会话超限时显式标记 `truncated`，避免产生看似完整但事件已被静默删除的诊断会话。
- crash 事件写入后执行 best-effort 强制刷新，缩短进程随即退出时的丢失窗口。
- 本变更不包含时间线 UI、导航 breadcrumb、脱敏、诊断包导出、异常洞察、请求回放、DevTools 或 OpenTelemetry 集成。

## Capabilities

### New Capabilities

- `diagnostic-session`: 定义诊断会话的数据模型、生命周期、事件关联、兼容 API、异常恢复和会话查询行为。

### Modified Capabilities

- `packet-storage`: 将全局记录列表升级为版本化的会话/事件存储，兼容旧格式，并以会话为边界执行保留、清空、排序和强制刷新。
- `http-capture-pipeline`: HTTP 事件改为经过统一 dispatch，在活动会话中分配关联信息，并让运行时开关遵循会话暂停/恢复语义。
- `crash-error-capture`: crash 事件遵循统一录制开关、绑定活动会话，并在持久化后进行 best-effort 强制刷新。
- `jank-analysis`: 卡顿事件遵循统一录制开关并绑定活动会话。
- `resource-monitor`: 资源采样遵循统一录制开关并绑定活动会话，暂停期间不继续制造记录。
- `resource-sample-aggregation`: 资源采样聚合必须以会话边界为硬边界，不跨 session 合并。
- `packet-record-ui`: 现有清空操作扩展为清空 sessions 与 records 并结束活动会话；抓包按钮继续使用 captureEnabled，但表现为会话暂停/恢复。

## Impact

- 公共 API：`ArgosConfig` 增加会话模式与保留配置；`ArgosManager` 增加会话生命周期和查询入口；`captureEnabled` 保留但由会话控制器承载语义。
- 数据模型：新增 session 模型；`ArgosPacketRecord` 增加 `sessionId`、`sequence` 等兼容字段。
- 数据流：`ArgosHttpMonitor`、`ArgosNativeCapture`、`ArgosCrashMonitor`、`ArgosJankMonitor`、`ArgosResourceMonitor` 统一通过 manager dispatch。
- 存储：`ArgosPacketStorage` 的缓存和序列化结构变为版本化信封，仍使用现有 `ArgosStorageAdapter`，需要旧列表格式的无损读取与迁移测试。
- UI：现有列表和详情继续可用；清空后同步回到 idle，抓包按钮沿用现有外观但控制 session 暂停/恢复；不新增会话时间线页面。
- 测试：新增状态机、自动/手动模式、旧数据迁移、并发顺序、异常恢复、会话淘汰、所有事件类型录制门控和 crash flush 测试。
