## 1. Session 与事件模型

- [x] 1.1 新增 `ArgosDiagnosticSession`、`ArgosSessionMode`、`ArgosSessionState`、`ArgosSessionEndReason` 和 `ArgosEventMetadata`，实现兼容未知字段的 JSON 序列化/反序列化
- [x] 1.2 扩展 `ArgosBaseModel` 以暴露可空事件元数据，扩展 `ArgosPacketRecord` 的可空 `sessionId`、默认 `sequence = 0` 与不可变复制方法，并保持旧构造器和旧 JSON 可用
- [x] 1.3 扩展 `ArgosConfig`，加入默认 automatic 的 sessionMode 和默认 5 的 maxSessions，并对非法配额提供明确断言或安全归一化
- [x] 1.4 从 `argos_inspector.dart` 导出新增公共类型，补充模型往返、旧记录降级、同毫秒唯一 id 和默认配置单元测试

## 2. 版本化 Session 存储

- [x] 2.1 将 `ArgosPacketStorage` 内存缓存重构为 schemaVersion 1 的 sessions/records 信封，定义新 key `argos_diagnostic_store_v1` 并保留 legacy key 常量
- [x] 2.2 实现新 key 优先读取、legacy List 回退迁移和未知 schemaVersion 只读保护；迁移写入新 key 时不得覆盖或删除 legacy key
- [x] 2.3 在统一 `_opChain` 上实现 begin、pause、resume、complete 和 interrupted-recovery 会话操作，保证 begin 排在首条事件前、complete 排在此前事件后
- [x] 2.4 更新 append 路径，使事件写入所属 session、更新 lastEventAt，并保留 `getAllAsync()` 的全局倒序兼容视图
- [x] 2.5 新增按 startedAt 倒序读取 sessions、按 sequence 升序读取指定 session records 的查询接口，并为不存在的 session 返回空列表
- [x] 2.6 实现 maxSessions 整体淘汰、每 session/per-kind 配额、activeSession 保护、truncated 标记和 legacy 历史桶配额
- [x] 2.7 更新 clear 同时删除新旧 key、清空内存信封并通过无循环依赖的回调通知 manager 回到 idle；保持 flush 和合并落盘语义
- [x] 2.8 增加新信封读取、legacy 迁移/回滚保留、未知版本保护、session 查询、整体淘汰、局部裁剪、clear 双 key 和串行顺序测试

## 3. Manager Session 控制器

- [x] 3.1 在 `ArgosManager` 中实现单活动会话状态机、无额外依赖的唯一 session id、同步 sequence 分配和 activeSession/sessionState 访问器
- [x] 3.2 实现 start/pause/resume/stop API 的幂等与状态转换，并把需要持久化保证的 stop/flush/clear 暴露为可等待操作
- [x] 3.3 把 `captureEnabled` 改为 sessionState 的兼容 getter/setter，覆盖 idle→start、recording→pause 和 paused→resume，移除独立 bool 状态源
- [x] 3.4 更新 `init()`：只配置一次 storageAdapter，按 automatic/manual 与 enableStorage 初始化会话，重复 init 不创建重复会话，再初始化已配置 monitors
- [x] 3.5 重写 `dispatch` 为唯一录制门控，给 model 与 record 分配一致 metadata，先 listener 后可选持久化，并向 crash 路径暴露 append 完成信号
- [x] 3.6 更新 App 生命周期处理：后台/detached 只 flush 不结束 activeSession，并在存储 hydration 时先恢复旧开放会话为 interrupted
- [x] 3.7 增加 automatic/manual、重复 init、start 幂等、pause/resume、stop、captureEnabled 映射、无 adapter listener-only、事件拒绝不消耗 sequence和中断恢复测试

## 4. 统一各采集链路

- [x] 4.1 将 Dart HTTP 正常/错误记录改为构建 record 后调用 manager dispatch，删除 monitor 内直接 append，并保持 hostWhiteList 与错误去重现有语义
- [x] 4.2 将 `ArgosNativeCapture` 解码后的 record 改为进入 manager dispatch，由 manager 重写 sessionId、sequence 和唯一 id，删除直接 storage append
- [x] 4.3 更新 crash monitor 使用统一 dispatch，并在 append 完成后触发不阻塞宿主 handler 的 best-effort flush，覆盖 flush 失败路径
- [x] 4.4 验证并调整 jank/resource monitor，使 paused/idle 时不产生 listener 或存储记录且不消耗 sequence，保留其既有检测和采样安装行为
- [x] 4.5 增加 network/native/crash/jank/resource 同 session 连续 sequence、各链路 paused 门控、HTTP host 规则和 crash handler 链式调用回归测试

## 5. 聚合、兼容 UI 与文档

- [x] 5.1 更新资源采样聚合，使 sessionId 变化以及 legacy 空 sessionId 与新 session 之间形成硬边界，并补充跨 session 聚合测试
- [x] 5.2 更新列表抓包按钮和清空流程：同步 recording/paused/idle 图标状态，清空后结束活动会话，并补充 start/pause/resume/clear widget 测试
- [x] 5.3 更新 README/README_zh，说明 automatic/manual session API、captureEnabled 兼容语义、查询接口、maxSessions 和 listener-only 用法
- [x] 5.4 更新 CHANGELOG，记录存储信封迁移、新 key 回滚策略，以及暂停行为扩展到 crash/jank/resource 的可观察变化
- [x] 5.5 更新 example 展示自动会话，并增加一个最小手动 start/pause/resume/stop 演示，不引入时间线 UI

## 6. 验证

- [x] 6.1 运行 `dart format` 覆盖所有变更 Dart 文件并确认无非预期格式差异
- [x] 6.2 运行 `flutter analyze`，修复本变更引入的全部 error/warning/info
- [x] 6.3 运行完整 `flutter test`，确认新增 session 测试与既有抓包、存储、APM、Widget Inspector 测试全部通过
- [x] 6.4 运行 `openspec validate diagnostic-session-model --strict`，确认 proposal、design、delta specs 与任务状态有效
- [x] 6.5 在 example 中人工验证：自动会话记录多类型事件、暂停期间无新增记录、恢复后 sequence 连续、停止后查询完整、kill/restart 后旧会话显示 interrupted
