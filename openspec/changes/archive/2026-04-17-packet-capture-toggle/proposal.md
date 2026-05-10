## Why

当前抓包开关（`enableStorage`）只能在初始化时通过 `KurilApmConfig` 静态配置，运行时无法动态关闭或开启。调试时需要随时暂停抓包以减少干扰，或在特定操作前重新开启，现有 API 无法支持这个需求。

## What Changes

- `KurilApmManager` 新增可写属性 `captureEnabled`（`bool`），运行时随时可切换，默认值由 `KurilApmConfig.enableStorage` 决定
- `_dispatchHttpInfo` 在写入存储和触发 listener 前检查 `captureEnabled`，为 `false` 时跳过记录
- `KurilPacketListPage` AppBar 右上角新增开关按钮（图标），实时反映并控制 `captureEnabled` 状态

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `http-capture-pipeline`: `_dispatchHttpInfo` 的存储和 listener 回调受 `captureEnabled` 约束
- `packet-record-ui`: 列表页新增开关入口

## Impact

- `lib/kuril_apm_manager.dart`: 新增 `captureEnabled` 属性
- `lib/apm/kuril_http_monitor.dart`: `_dispatchHttpInfo` 增加 `captureEnabled` 判断
- `lib/ui/kuril_packet_list_page.dart`: AppBar 新增开关按钮
