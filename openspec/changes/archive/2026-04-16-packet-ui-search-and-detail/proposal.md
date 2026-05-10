## Why

`KurilPacketListPage` 目前无任何搜索或过滤能力，当抓包记录较多时（尤其调试高频接口时）定位目标请求非常耗时。`KurilPacketDetailPage` 的请求头区域使用固定 80px 宽的 label 列，长 header key（如 `x-request-package-sign-version`）会被截断；请求和响应信息混在同一列表中，滚动成本高；错误请求（`error != null`）也没有特殊展示。

## What Changes

**列表页：**
- 新增搜索栏：按 URL 关键词实时过滤（大小写不敏感）
- 新增 Method 快捷过滤 chip（GET / POST / ALL），可与搜索栏组合使用
- 过滤后若无结果，展示"无匹配记录"提示

**详情页：**
- 请求/响应拆分为两个 Tab（`请求` / `响应`），减少单页滚动长度
- Header 区域改为上下排列（key 独占一行，value 换行展示），解决长 key 被截断问题
- 错误请求（`record.error != null`）在响应 Tab 顶部以红色警告卡片展示错误信息
- 请求 Tab 新增 Query Params 区块（解析 URL query string 展示 key-value）

## Capabilities

### New Capabilities

_(无全新 capability，均为对现有 UI 的改进)_

### Modified Capabilities

- `packet-record-ui`：更新列表页过滤需求 + 更新详情页展示需求

## Impact

- `lib/ui/kuril_packet_list_page.dart`：添加搜索栏、过滤逻辑
- `lib/ui/kuril_packet_detail_page.dart`：改为 TabBarView、Header 展示调整、错误卡片、Query Params
- 不影响 `KurilPacketRecord` 数据模型
- 不新增外部依赖
