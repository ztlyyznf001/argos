## Why

七个主 spec 文件（`curl-builder`、`dynamic-proxy-provider`、`http-capture-pipeline`、`packet-record-ui`、`packet-route-grouping`、`packet-storage`、`packet-visual-polish`）在归档同步时保留了 delta 文件的 `## ADDED Requirements` 标题（或干脆没有顶层小节标题），导致 `openspec` CLI 无法解析出其中的需求：`openspec list --specs` 对这七个能力全部报告 `requirements 0`，`openspec validate --specs` 也全部失败。这些能力实际上都有完整的需求与场景内容，只是对工具链不可见——spec 树因此无法作为可信的事实来源使用。

## What Changes

- 将七个受影响的主 spec 文件的顶层结构改写为规范的主 spec 格式：`# <capability> Specification` / `## Purpose` / `## Requirements`，其下保留原有的 `### Requirement:` 与 `#### Scenario:` 内容。
- 逐个补写各能力的 `## Purpose` 段落（原 delta 文件中不存在该段落）。
- 需求与场景的正文**逐字保留**，不新增、不删除、不改写任何需求语义——这是一次纯粹的文档结构修复。
- 新增 `spec-format-conventions` 能力，把「主 spec 的规范文件格式」与「归档同步必须产出可通过 `openspec validate --specs` 的主 spec」固化为需求，避免后续 change 归档时重复引入同一问题。

## Capabilities

### New Capabilities
- `spec-format-conventions`: 规定 `openspec/specs/<capability>/spec.md` 的规范文件结构，以及 delta spec 同步进主 spec 时必须完成的格式转换与校验。

### Modified Capabilities
<!-- 无。七个受影响 spec 的需求语义不变，仅修复承载它们的文件结构，不属于 spec 级行为变更。 -->

## Impact

- 影响文件：`openspec/specs/{curl-builder,dynamic-proxy-provider,http-capture-pipeline,packet-record-ui,packet-route-grouping,packet-storage,packet-visual-polish}/spec.md`（仅改标题结构、补 Purpose）。
- 不涉及任何 Dart 源码、`lib/`、`example/` 或构建产物；无运行时行为变化，无 API 变更。
- 修复后 `openspec list --specs` 应对全部 12 个能力报告非零需求数，`openspec validate --specs` 应全部通过。
