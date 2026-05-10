## Context

`ArgosPacketStorage` 当前直接依赖 `mmkv` 包：初始化 `MMKV` 实例、调用 `encodeString`/`decodeString`/`removeValue`。这使 argos 携带了 MMKV 的原生 SDK（Android/iOS），宿主 App 无法选择其他存储后端，也无法在不使用 MMKV 的环境中干净地集成。

存储操作可以归纳为三个语义接口：写入字符串、读取字符串、删除键。JSON 序列化/反序列化和条数限制逻辑仍由 `ArgosPacketStorage` 自身维护，adapter 只负责持久化原始字符串。

## Goals / Non-Goals

**Goals:**
- 定义 `ArgosStorageAdapter` 抽象类，声明最小化存储接口
- `ArgosPacketStorage` 通过 adapter 委托所有 I/O，自身不再 import `mmkv`
- `ArgosConfig` 接受 `storageAdapter` 注入，`ArgosManager` 在 init 时传递给 storage
- 移除 `pubspec.yaml` 中 `mmkv`、`path_provider` 依赖

**Non-Goals:**
- 不提供内置的 MMKV adapter 实现（移交宿主维护）
- 不提供 SharedPreferences 或其他官方 adapter 实现
- 不保留向后兼容的 MMKV fallback

## Decisions

### adapter 接口使用同步还是异步？

选择**异步**（`Future<String?> read()`、`Future<void> write()`、`Future<void> clear()`）。

理由：宿主存储实现可能本身是异步的（SharedPreferences、文件 I/O）；`ArgosPacketStorage` 内部已通过 `_writeChain` 串行化写操作，异步接口与现有链式模型一致，无需额外改造。

替代：同步接口简单，但限制了宿主实现的范围（MMKV 本身是同步的，但其他方案不是）。

### adapter 接口是否包含 key？

**不包含**。adapter 面向 argos 的单一存储槽（一个 JSON 字符串），不需要通用 KV 接口。接口方法仅有 `read`、`write(String value)`、`clear`，语义清晰。

替代：暴露 `read(String key)` 等通用 KV 接口，过度设计，宿主需要关心 key 名称。

### adapter 为 null 时的行为

未注入 adapter → `enableStorage` 视同 `false`，所有写入静默跳过，`getAllAsync` 返回空列表。不抛异常，不打印 warning（宿主主动不注入是合法选择）。

### 移除 path_provider 依赖

`path_provider` 仅在 `_removeLegacyFile` 中使用（清理旧格式 JSON 文件）。该逻辑随 MMKV 迁移一并删除，`path_provider` 可从 pubspec 移除。

## Risks / Trade-offs

- **Breaking change（宿主迁移成本）**: 所有使用 `enableStorage: true` 的宿主必须自行实现并注入 adapter → Mitigation: 文档提供标准 MMKV adapter 示例代码（不作为包内代码维护）
- **存储静默禁用**: adapter 未注入但 `enableStorage: true` 时无警告 → 可接受，宿主明确知道自己没有注入

## Migration Plan

1. 宿主侧新建 MMKV adapter 实现类（参考示例代码）
2. 在 `ArgosConfig` 中注入 adapter
3. 移除宿主 pubspec 中不需要通过 argos 间接引入的 mmkv 配置（若有）
