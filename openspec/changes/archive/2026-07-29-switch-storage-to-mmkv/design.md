## Context

`argos` 是一个 Flutter plugin，其 `packet-storage` 能力最初以 MMKV 作为本地持久化引擎。宿主 App（echo 移动端）在自身 Podfile 中锁定了一个较旧版本的 MMKV 原生 Pod，而 `mmkv` Flutter 插件在初始化时会调用 `MMKVConfigDefault()`——该 API 在旧版原生 SDK 中不存在，导致 iOS 构建失败。

作为临时修复（commit `c38ea8a`），存储实现被替换为 `path_provider` + 单个 JSON 文件。这解决了构建问题，但：
- 每次 `append` 都需要 read→append→write 整个列表，随记录增多 I/O 放大明显；
- 崩溃中途写入可能导致文件损坏；
- spec 仍声明由 MMKV 承担，实现与规约不一致。

本次变更的目标是把实现切回 MMKV，并在设计上给出根治 iOS Pod 冲突的路径。

## Goals / Non-Goals

**Goals:**
- 使用 MMKV 作为 `ArgosPacketStorage` 的底层存储，恢复增量追加写入
- 给出一套稳定的 iOS Pod 版本协调方案，避免重现 `MMKVConfigDefault()` 缺失错误
- 保持 `ArgosPacketStorage` 的公共 API 语义（`append`/`getAllAsync`/`clear`）不变
- 在 MMKV 初始化失败时不 crash，按“禁用存储”语义降级

**Non-Goals:**
- 不支持将历史 JSON 文件记录自动迁移到 MMKV（直接丢弃；用户未依赖跨版本历史数据）
- 不改变 `maxPacketRecords` 淘汰策略或记录的数据模型
- 不替换上层 UI 对存储 API 的调用方式

## Decisions

### D1: 依赖 `mmkv` Flutter 插件（而非通过 FFI 自研绑定）

- **选择**: 使用 pub.dev 上官方维护的 `mmkv: ^1.3.x`
- **理由**: 已验证的跨平台封装，减少原生桥接工作量；社区活跃
- **替代**: 通过 `dart:ffi` 绑定 MMKV C++ 动态库——工作量巨大，调试成本高，放弃

### D2: 通过 Podfile `post_install` 统一 MMKV 版本

- **选择**: 本插件自身不含原生 iOS 代码（`pubspec.yaml` 仍是占位 `some_platform` 配置），因此 MMKV 的 Pod 依赖由 `mmkv` Flutter 插件的 podspec 承载，我们不再新增插件级 podspec。版本协调在两处完成：(1) 在 `example/ios/Podfile` 的 `post_install` 钩子中提供统一 MMKV 版本的示例；(2) 在 README 中给出宿主 App 侧的 `post_install` 模板与冲突排查步骤，并声明 `ArgosConfig.enableStorage = false` 作为最终兜底。
- **理由**: Pod 依赖解析冲突是 iOS 生态常见问题，没有唯一"完美"答案。宿主 Podfile + 文档指引是插件项目唯一能从自身仓库可靠控制的层面。
- **替代**: 
  - 给本插件新增 `ios/` 目录与 podspec 以显式声明 MMKV 下限——会引入一批本不需要的原生模板代码，收益有限，放弃。
  - 在 plugin 侧直接 vendoring MMKV 源码——体积大、维护负担高，放弃。
  - 在插件里做 Objective-C runtime 检查并回落——脆弱，不如显式开关透明。

### D3: 单键存 JSON 列表 vs 多键一条一记录

- **选择**: 沿用现有序列化格式，把整个 `List<ArgosPacketRecord>.toJson()` 作为 JSON 字符串存入 MMKV 的单个 key（例如 `argos_packet_records`）
- **理由**: 
  - 改动最小、语义等价，写入/读取路径与当前 JSON 文件版本一一对应；
  - `maxPacketRecords` 默认 200 条，单 key 的读写成本仍可接受；
  - MMKV 的 mmap 写入相较 `File.writeAsString` 显著更快，解决了当前 I/O 放大问题。
- **替代**: 每条记录一个 key（key 为时间戳）——读取时需要枚举所有 key 并排序，性能不一定更好，且破坏现有序列化边界；仅在未来单次追加成为瓶颈时考虑。

### D4: MMKV 初始化失败的降级

- **选择**: 在 `ArgosPacketStorage` 首次使用时惰性 `MMKV.defaultMMKV()`；若抛出异常（如原生 SDK 缺失方法），捕获后把内部状态置为 `disabled`，后续 `append` 为 no-op，`getAllAsync` 返回空列表，`clear` 为 no-op，同时通过 `debugPrint` 输出一次性告警。
- **理由**: plugin 不应让宿主 App 因存储能力失败而 crash；降级语义与 `enableStorage=false` 等价，保留上层功能可用性。
- **替代**: 直接抛出初始化异常并由调用方处理——会把实现细节泄露到上层，违反封装。

### D5: 不做历史数据迁移

- **选择**: 切换到 MMKV 时不读取旧的 `argos_packet_records.json`；必要时在首次初始化后尝试删除该文件以免遗留。
- **理由**: 抓包数据本身是诊断性的短生命周期数据，用户不依赖跨版本一致性；迁移代码的维护成本大于收益。
- **替代**: 一次性迁移逻辑——增加复杂度且只在一次发布窗口有意义，放弃。

## Risks / Trade-offs

- **风险**: 宿主 App 仍锁死旧版 MMKV Pod，D2 的指引被忽略 → **缓解**: D4 的降级策略保证不 crash；在 README 明确列出"若看到 `MMKVConfigDefault` 相关构建错误，请按 X 处理，或将 `enableStorage` 置为 false"。
- **风险**: 单 key JSON 列表在极端记录条数（几千条）下读取耗时 → **缓解**: `maxPacketRecords` 默认 200，并在文档中说明上限建议；若未来成为瓶颈再切 D3 的备选方案。
- **风险**: MMKV 加密/多进程等高级特性未使用，未来需求变化需重做接口 → **缓解**: 当前上层 API 已抽象，可以在不改调用方的前提下替换底层实现。
- **权衡**: 放弃自动迁移历史数据 → 换取实现简单与更短的发布周期；在 proposal 中已标注为 BREAKING。

## Migration Plan

1. 在 `pubspec.yaml` 中加入 `mmkv: ^1.3.0`（保留或移除 `path_provider` 视是否需要清理旧文件而定）。
2. 重写 `ArgosPacketStorage`：首次访问时惰性 `MMKV.defaultMMKV()`；对单 key 做 JSON 编解码；捕获初始化异常切换到 disabled 状态。
3. 更新 `example/ios/Podfile`，在 `post_install` 钩子中加入 MMKV 版本协调示例，作为宿主集成的参考。
4. 更新 README：存储说明、iOS Pod 冲突排查指引、`enableStorage` 兜底。
5. 运行 `flutter pub get`、`cd example/ios && pod install`、`flutter build ios --no-codesign` 与 `flutter build apk`，验证两端构建通过。
6. 手动验证：抓包→kill app→重启→记录可恢复；`clear()` 后列表为空；初始化失败时（可用 mock 验证）上层不报错。

**回滚**: 如果 MMKV 方案在 CI 或灰度发现新阻塞，可直接还原本次 PR 回到 `path_provider` 实现。

## Open Questions

- 是否需要在切换到 MMKV 后尝试主动删除旧的 `argos_packet_records.json` 文件？（倾向：删除，避免用户磁盘残留；待实施时确认）
- 是否需要给 MMKV 实例指定独立的 `mmapID`（如 `"argos"`），以避免和宿主 App 自己的 MMKV 根命名冲突？（倾向：是，独立命名更安全）
