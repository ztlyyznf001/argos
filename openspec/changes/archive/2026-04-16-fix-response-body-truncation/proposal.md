## Why

当前抓包链路会在序列化 `KurilPacketRecord` 时把超过 100KB 的响应体直接截断并追加 `"[TRUNCATED]"`。这会导致详情页展示、复制响应体和问题排查时拿到的是不完整内容，尤其对较大的 JSON 响应几乎失去调试价值。

## What Changes

- 调整抓包存储规则：文本响应体默认完整保存，不再因为 100KB 阈值被截断
- 保留非文本响应只记录元数据的现有行为，避免把图片、音视频或任意二进制内容写入文本字段
- 明确 UI 层读取到的 `responseBody` 应与实际捕获到的文本响应一致，不再依赖 `"[TRUNCATED]"` 作为大响应提示
- 为大文本响应补充实现约束与验证，确保写入、读取和详情页展示链路都能处理完整响应体

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `packet-storage`: 响应体存储规则从“超过 100KB 截断”调整为“文本响应体完整保存，非文本响应不保存 body”

## Impact

- `lib/model/kuril_http_info_model.dart`: 去掉或重构 `responseBody` 的截断逻辑
- `lib/storage/kuril_packet_storage.dart`: 继续承接更大的文本响应快照写入与读取
- `lib/ui/kuril_packet_detail_page.dart`: 直接展示完整响应体，不再面向截断标记设计
- 测试与 spec：需要补充大文本响应的存储与展示场景，覆盖回归风险
