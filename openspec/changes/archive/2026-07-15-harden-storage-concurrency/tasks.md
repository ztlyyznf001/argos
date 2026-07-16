## 1. 串行操作队列

- [x] 1.1 将 `_writeChain` 泛化为 `_opChain`，提供一个 `_enqueue(task)` 把任意异步任务串到链上并返回其 `Future`
- [x] 1.2 让 `append`/`appendRecord` 经 `_opChain` 执行写入任务（保持返回该任务的 `Future`，供测试等待）
- [x] 1.3 让 `clear()` 经 `_opChain` 执行清空任务，不再直接调用 `_adapter.clear()`
- [x] 1.4 让 `getAllAsync()` 经 `_opChain` 执行读取任务，返回时反映此前入链的全部操作

## 2. 内存缓存

- [x] 2.1 引入 `List<Map<String, dynamic>>? _cache`，首个入链操作时从 adapter `read + jsonDecode` 惰性水合一次
- [x] 2.2 写入任务在 `_cache` 上 `add` + `_trimKind`（按 kind 分区淘汰逻辑复用，不改语义），标记 dirty（不在此处立即落盘）
- [x] 2.3 读取任务从 `_cache` 映射为 `ArgosPacketRecord` 并按 `startTimestamp` 倒序返回，不再读 adapter、不再解码
- [x] 2.4 清空任务置 `_cache = []`，立即落盘 `adapter.clear()`（clear 强制 flush）
- [x] 2.5 `setAdapter()` 置 `_cache = null`，下次入链操作从新 adapter 重新水合

## 3. 合并落盘

- [x] 3.1 在 `ArgosConfig` 新增 `storagePersistInterval`（默认如 `Duration(seconds: 5)`），并让 `ArgosManager` 在 init 时配置到存储（如 `ArgosPacketStorage.instance.persistInterval = ...`）
- [x] 3.2 写入标记 dirty 后调度节流 flush：无待定定时器时启动 `persistInterval` 定时器，到点后经 `_opChain` 执行一次 `jsonEncode(_cache)` + `adapter.write`，清 dirty 与定时器
- [x] 3.3 `Duration.zero` 时退化为「每次写入即落盘」（不启动定时器，写入任务内直接落盘）
- [x] 3.4 新增 `Future<void> flush()`：若 dirty 则取消待定定时器并立即经 `_opChain` 落盘；无 dirty 时为 no-op，返回已完成的 `Future`
- [x] 3.5 `ArgosManager` 在 init 时注册 `WidgetsBindingObserver`，在 `AppLifecycleState.paused`/`detached` 回调中调用 `ArgosPacketStorage.instance.flush()`

## 4. 健壮性

- [x] 4.1 持久化（`adapter.write`）失败时沿用 `try/catch + debugPrint`，保持 `_cache` 为最新事实来源，dirty 保留待下次成功落盘自愈，链不中断
- [x] 4.2 `_adapter == null` 时的行为与既有一致（读返回空、写为 no-op、flush 为 no-op）

## 5. 验证

- [x] 5.1 单元测试：先写入再 `clear()`（写入在途），断言最终为空，数据不复活
- [x] 5.2 单元测试：先 `clear()` 再写入，断言新记录保留
- [x] 5.3 单元测试：连续快速多次写入不等待，断言全部按序生效、无丢更新
- [x] 5.4 单元测试：写入后紧接 `getAllAsync()` 反映该写入（读观察全序，即便尚未落盘）
- [x] 5.5 单元测试：`setAdapter` 预置数据（直接 `adapter.write`）后读取从新 adapter 水合出预置数据
- [x] 5.6 单元测试：水合只发生一次（多次读取不重复读 adapter）—— 用计数 adapter 断言 `read` 调用次数
- [x] 5.7 单元测试：合并落盘——一个周期内多次写入后 adapter 的 `write` 调用次数少于写入次数（计数 adapter）
- [x] 5.8 单元测试：`flush()` 强制立即落盘，落盘后 adapter 中数据与内存一致
- [x] 5.9 单元测试：`storagePersistInterval == Duration.zero` 时每次写入都落盘（`write` 次数等于写入次数）
- [x] 5.10 回归：既有存储配额与列表页测试全部通过；`flutter analyze` 无告警
