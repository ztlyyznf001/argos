## Context

`openspec` 的 spec 解析器按顶层小节（`##`）定位需求：只有落在 `## Requirements` 小节下的 `### Requirement:` 才会被识别。delta spec 使用 `## ADDED Requirements` 等操作标题，这些标题在归档同步进主 spec 时**必须**被转换成 `## Requirements`。

历史上的若干次归档跳过了这一步，直接把 delta 文件原样搬进了 `openspec/specs/`。当前七个主 spec 因此对工具链完全不可见：

| Spec 文件 | 当前顶层结构 | 解析结果 |
| --- | --- | --- |
| `curl-builder` | `## ADDED Requirements` | 0 requirements |
| `http-capture-pipeline` | `## ADDED Requirements` | 0 requirements |
| `packet-record-ui` | `## ADDED Requirements` | 0 requirements |
| `packet-route-grouping` | `## ADDED Requirements` | 0 requirements |
| `packet-storage` | `## ADDED Requirements` | 0 requirements |
| `packet-visual-polish` | `## ADDED Requirements` | 0 requirements |
| `dynamic-proxy-provider` | 无任何 `##` 小节，首行即 `### Requirement:` | 0 requirements |

作为对照，格式正确的主 spec（`release-process`、`native-capture-example`，以及本次刚同步的 `crash-error-capture` / `jank-analysis` / `resource-monitor`）均能被正常解析并通过 `openspec validate --specs`。

约束：这七个文件的需求正文是既有能力的唯一书面记录，**不得**在本次修复中被改写或丢失。

## Goals / Non-Goals

**Goals:**
- 让全部 12 个主 spec 都能被 `openspec` 解析出正确的需求数，并通过 `openspec validate --specs`。
- 逐字保留七个受影响 spec 的所有 `### Requirement:` / `#### Scenario:` 正文。
- 把主 spec 的规范格式固化为一条可校验的需求，阻止后续归档再次引入同样的问题。

**Non-Goals:**
- 不重写、不补充、不删减任何既有需求的语义内容（`## Purpose` 段落除外——它是新增的结构性文字，不承载需求）。
- 不触碰 `lib/`、`example/` 或任何 Dart 源码；本次改动零运行时影响。
- 不回头修改 `openspec/changes/archive/` 下已归档的 delta 文件——它们保留 `## ADDED Requirements` 是正确的，delta 格式本就如此。
- 不改动 `openspec` CLI 本身或其解析规则。

## Decisions

### 决策一：改主 spec 文件，而不是放宽解析器

把 `## ADDED Requirements` 也当作主 spec 的合法需求容器，看似能一次性「修好」七个文件，但会让 delta 格式与主 spec 格式永久混淆，且 `openspec` 是外部依赖、不在本仓库控制范围内。修文件是唯一正确且可持续的方向。

### 决策二：目标结构统一为「标题 + Purpose + Requirements」

```markdown
# <capability> Specification

## Purpose

<一段话说明该能力覆盖的范围>

## Requirements

### Requirement: ...
#### Scenario: ...
```

这与 `release-process`、`crash-error-capture` 等已正确同步的 spec 完全一致。虽然 `native-capture-example` 缺少 `# <capability> Specification` 首行也能解析（说明标题行非解析必需），但统一带上标题可读性更好，且与多数现有文件一致。

### 决策三：`## Purpose` 由能力名与需求内容归纳，一句话为限

七个 delta 文件都没有 Purpose 段落，必须新写。Purpose 是描述性的、不含 SHALL 的散文，不参与解析，因此不存在「凭空造需求」的风险。归纳时只复述该 spec 内已有需求覆盖的范围，不引入新主张。

### 决策四：`dynamic-proxy-provider` 单独处理

它是唯一一个连 `##` 小节都没有的文件，需要同时补 `# 标题`、`## Purpose` 和 `## Requirements` 三层结构，而其余六个只需把 `## ADDED Requirements` 一行替换为 `## Requirements` 并在其上插入标题与 Purpose。

### 决策五：以 `openspec validate --specs` + `openspec list --specs` 的需求计数作为验收信号

每个文件改完后逐个 validate，并核对该 spec 的需求数与文件内 `### Requirement:` 的实际条数一致——这能同时抓住「解析失败」和「解析成功但漏读了部分需求」两类问题。

## Risks / Trade-offs

- **[改写标题时误伤需求正文，导致既有需求丢失]** → 编辑严格限定为「在文件顶部插入标题与 Purpose」+「替换那一行 `## ADDED Requirements`」，不碰 `###` 及以下任何一行；改后用需求条数比对校验（改前 grep `^### Requirement:` 计数，改后与 `openspec list --specs` 报告数字对照）。
- **[`## Purpose` 归纳时不慎引入原本不存在的主张]** → Purpose 限定为一句范围描述，禁用 SHALL/MUST 等规范性动词。
- **[新增的 `spec-format-conventions` 能力约束的是流程而非代码，无法自动执行]** → 它的价值在于让「归档时必须转换格式并通过 validate」成为一条可被 review 引用的成文需求；配套的兜底是把 `openspec validate --specs` 作为归档流程的显式验收步骤，而不是依赖记忆。
