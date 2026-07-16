# spec-format-conventions Specification

## Purpose
本能力描述 OpenSpec 主 spec 文件（`openspec/specs/<capability>/spec.md`）的规范结构，以及 change 的 delta spec 在归档同步过程中如何转换为主 spec 结构。它涵盖主 spec 的顶层小节布局、delta 操作标题的处理方式、需求内容在格式转换中的保留原则，以及主 spec 的校验预期。

## Requirements
### Requirement: 主 spec 文件的规范结构
`openspec/specs/<capability>/spec.md` SHALL 采用如下顶层结构：首行为 `# <capability> Specification`，其后为 `## Purpose` 小节，再其后为 `## Requirements` 小节；所有 `### Requirement:` 条目 MUST 位于 `## Requirements` 小节之下。

#### Scenario: 主 spec 使用规范结构
- **WHEN** 一个能力的主 spec 文件被创建或更新
- **THEN** 该文件包含 `# <capability> Specification` 标题、`## Purpose` 小节与 `## Requirements` 小节，且全部需求条目位于 `## Requirements` 之下

#### Scenario: 主 spec 不得保留 delta 操作标题
- **WHEN** 检查 `openspec/specs/` 下任一主 spec 文件
- **THEN** 该文件不包含 `## ADDED Requirements`、`## MODIFIED Requirements`、`## REMOVED Requirements`、`## RENAMED Requirements` 等 delta 操作标题

### Requirement: 归档同步必须完成 delta 到主 spec 的格式转换
在将 change 的 delta spec 同步进主 spec 时，系统 SHALL 把 delta 操作标题（如 `## ADDED Requirements`）转换为主 spec 的 `## Requirements` 小节，并补齐 `# <capability> Specification` 标题与 `## Purpose` 小节；SHALL NOT 将 delta 文件原样复制进 `openspec/specs/`。

#### Scenario: 新能力首次同步进主 spec
- **WHEN** 一个 change 的 delta spec 引入了一个 `openspec/specs/` 中尚不存在的新能力，并被同步进主 spec
- **THEN** 生成的主 spec 文件采用规范结构，delta 的 `## ADDED Requirements` 标题被替换为 `## Requirements`，并新增了标题行与 `## Purpose` 小节

#### Scenario: 原样复制 delta 文件被视为错误
- **WHEN** 某次同步把 delta 文件连同其 `## ADDED Requirements` 标题原样写入 `openspec/specs/<capability>/spec.md`
- **THEN** 该结果不符合本规范，须在归档完成前修正为主 spec 结构

### Requirement: 需求内容在格式转换中逐字保留
在修复或转换 spec 文件结构时，系统 SHALL 逐字保留所有 `### Requirement:` 与 `#### Scenario:` 的正文，SHALL NOT 借格式修复之机新增、删除或改写任何需求语义。

#### Scenario: 转换前后需求条数一致
- **WHEN** 一个 spec 文件的顶层结构被修复
- **THEN** 修复后文件中 `### Requirement:` 的条数与修复前完全一致，且每条需求的名称与正文未被改动

#### Scenario: 新增的 Purpose 不承载需求
- **WHEN** 为一个原本缺少 `## Purpose` 的 spec 补写该小节
- **THEN** 该小节仅以描述性语言说明能力范围，不含 SHALL/MUST 等规范性动词，不构成新需求

### Requirement: 主 spec 必须通过校验
`openspec/specs/` 下的每个主 spec SHALL 通过 `openspec validate --specs`，且 `openspec list --specs` 报告的需求数 MUST 为非零并与文件内实际的 `### Requirement:` 条数一致。

#### Scenario: 校验作为归档的验收条件
- **WHEN** 一个 change 完成 delta spec 同步、准备归档
- **THEN** `openspec validate --specs` 对受影响的能力全部通过，且这些能力的需求数非零

#### Scenario: 零需求视为解析失败
- **WHEN** `openspec list --specs` 对某个存在需求条目的能力报告 `requirements 0`
- **THEN** 该能力的 spec 文件结构被判定为损坏，须修复其顶层小节结构
