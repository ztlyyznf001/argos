## Why

`kuril_monitor` 已经具备基础的 HTTP 监控能力，但拦截到的请求数据只通过回调透传，没有持久化存储、也没有可视化界面，开发者无法在 App 内直接查看历史抓包记录，调试体验差。

## What Changes

- 新增 **抓包记录存储**：将拦截到的 HTTP 请求/响应完整信息（URL、Method、Header、Body、状态码、耗时）序列化后用 MMKV 持久化存储。
- 新增 **抓包记录 UI**：提供一个开箱即用的 Flutter Widget（页面），列出所有历史抓包记录，并可点击查看单条详情（请求头、请求体、响应头、响应体）。
- 新增 **存储管理**：支持清空所有记录，并限制最大存储条数（防止无限增长）。
- 扩展 `KurilApmManager` / `KurilApmConfig`：增加是否启用抓包存储的开关，以及最大记录条数配置项。

## Capabilities

### New Capabilities

- `packet-storage`: 使用 MMKV 持久化存储抓包记录，提供读取、写入、清空接口。
- `packet-record-ui`: 提供抓包记录列表页及详情页 Widget，展示请求/响应的完整信息。

### Modified Capabilities

（无现有 spec 需要修改）

## Impact

- **依赖变更**：plugin 本体（`kuril_monitor`）引入 `mmkv` 依赖；example 工程可能也需添加。
- **影响文件**：
  - `lib/model/kuril_http_info_model.dart` — 可能需要增加 JSON 序列化方法
  - `lib/apm/kuril_http_monitor.dart` — 在 `recordResponse` 后触发存储写入
  - `lib/kuril_apm_manager.dart` — 暴露存储/UI 入口
  - `lib/config/kuril_apm_config.dart` — 新增配置字段
  - 新增文件：`lib/storage/`, `lib/ui/`
- **无 breaking change**：所有新功能默认关闭，现有使用方式不受影响。
