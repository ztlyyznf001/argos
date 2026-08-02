## Why

当前 automatic 模式把一次进程运行视为一个持续会话：短暂切后台时语义稳定，但长时间后台、超长前台运行和用户/租户上下文切换仍会把多轮无关诊断混在同一个 sessionId 中。需要在保持现有默认行为和手动模式兼容的前提下，提供可选择、可预测的自动分段策略。

## What Changes

- 为 automatic 模式增加可配置的会话策略：保留当前 process 策略作为默认值，并新增 opt-in adaptive 策略。
- adaptive 策略在 App 长时间处于后台后自动结束旧会话，并在恢复时创建新会话；短暂后台仍继续原 sessionId。
- adaptive 策略在活动会话超过最大时长时，于下一条可接受事件进入统一 dispatch 前原子切换到新会话。
- 支持宿主提供稳定的诊断上下文指纹；用户、租户或环境上下文变化时自动切分会话，相同上下文不重复切分。
- 为自动切分增加明确的持久化结束原因，并保证 session 完成、下一 session 创建和事件 sequence 分配沿用现有串行顺序。
- 手动模式、显式 pause/resume/stop、路由变化和短暂 lifecycle 抖动不触发隐式切分。
- 更新示例、README、CHANGELOG 和测试，说明何时生成新的 sessionId。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `diagnostic-session`: 扩展 automatic 模式的策略配置、后台超时/最大时长/上下文变化分段、结束原因及 lifecycle 行为。

## Impact

- 公共 API：`ArgosConfig`、诊断会话策略/上下文模型、`ArgosSessionEndReason`。
- 运行时：`ArgosManager` 的 lifecycle 观察、统一 dispatch 前策略判断与会话原子 rollover。
- 持久化：复用现有 session 串行队列和 tolerant JSON 解析，不改变存储 schemaVersion，也不增加第三方依赖。
- 文档与验证：README、README_zh、CHANGELOG、example，以及会话状态机、生命周期、上下文切换、并发顺序和兼容性测试。
- 本变更不包含事故触发式 Session、前置事件环形缓冲、按路由切分或交互 breadcrumb；这些保留为后续独立能力。
