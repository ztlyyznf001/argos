## 1. 建立基线

- [x] 1.1 记录修复前各 spec 的需求条数基线（`grep -c '^### Requirement:'`）：curl-builder 6、dynamic-proxy-provider 4、http-capture-pipeline 7、packet-record-ui 13、packet-route-grouping 3、packet-storage 8、packet-visual-polish 7，合计 48
- [x] 1.2 记录修复前 `openspec list --specs` 的输出（七个能力均为 `requirements 0`），作为对照

## 2. 修复六个带 `## ADDED Requirements` 标题的 spec

- [x] 2.1 修复 `openspec/specs/curl-builder/spec.md`：插入 `# curl-builder Specification` 标题与 `## Purpose` 小节，将 `## ADDED Requirements` 替换为 `## Requirements`，不改动任何 `###`/`####` 正文
- [x] 2.2 修复 `openspec/specs/http-capture-pipeline/spec.md`：同 2.1 的处理方式
- [x] 2.3 修复 `openspec/specs/packet-record-ui/spec.md`：同 2.1 的处理方式
- [x] 2.4 修复 `openspec/specs/packet-route-grouping/spec.md`：同 2.1 的处理方式
- [x] 2.5 修复 `openspec/specs/packet-storage/spec.md`：同 2.1 的处理方式
- [x] 2.6 修复 `openspec/specs/packet-visual-polish/spec.md`：同 2.1 的处理方式

## 3. 修复缺少顶层小节的 spec

- [x] 3.1 修复 `openspec/specs/dynamic-proxy-provider/spec.md`：该文件首行即 `### Requirement:`，需补齐 `# dynamic-proxy-provider Specification` 标题、`## Purpose` 小节与 `## Requirements` 小节三层结构

## 4. 校验

- [x] 4.1 运行 `openspec validate --specs`，确认七个受影响能力全部通过
- [x] 4.2 运行 `openspec list --specs`，确认七个能力的需求数与 1.1 的基线逐一相等（6/4/7/13/3/8/7），且全部 12 个能力均为非零
- [x] 4.3 用 `git diff` 复核七个文件的改动仅限于文件顶部新增的标题/Purpose 行与被替换的那一行小节标题，`###`/`####` 正文零改动

## 5. 固化格式约定

- [x] 5.1 确认 `spec-format-conventions` delta spec 的四条需求已就绪（主 spec 规范结构、归档同步须转换格式、需求内容逐字保留、主 spec 必须通过校验）
- [x] 5.2 归档本 change 时，同步 `spec-format-conventions` 至 `openspec/specs/`，且同步结果本身必须符合它所规定的格式（自举校验：新 spec 需通过 `openspec validate --specs` 且需求数非零）
