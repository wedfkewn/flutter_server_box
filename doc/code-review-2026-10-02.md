# ServerBox 代码检查（2026-10-02）

本次检查针对当前工作区，包括尚未提交的界面重构、服务检测改动。完成了 Dart 全量静态检查、Flutter 全量测试，并重点阅读连接与自动检测、数据迁移与同步、设置页面和 Monitor 命令执行路径。检索范围包含 lib、monitor/src、crates 中的 516 个 Dart/Rust 源文件；并非逐行人工审计全部源文件或第三方依赖。

## 优先处理的发现

### 1. P2：断开服务器后，自动服务检测继续派发后续批次

- 位置：[external_probe_controller.dart](../lib/core/service/external_probe_controller.dart) 第 78、103 行；[single.dart](../lib/data/provider/server/single.dart) 第 662、896 行。
- 触发条件：自动检测已经开始，尚有未执行批次时手动断开服务器。
- `maybeAutoCheck(false)` 只更新连接标记，没有取消运行中的队列；批次循环也不检查连接标记。后续 SSH 批次调用 `ensureExec()`，最终通过 `ensureShellClient()` 创建新的连接。因此“手动断开”不能阻止尚未派发的自动检测重新连接。
- 单独回归复现：断开并完成第一批后，预期 runner 只调用 1 次，实际调用 2 次。这直接证明队列继续派发；重新连接的后果由上述调用路径确认，未连接用户的真实服务器做端到端复现。
- 建议：在断开时取消自动任务的 generation，禁止后续批次；允许已经开始的有界请求结束，并区分手动发起的检测与自动检测。

### 2. P2：默认语言初始化被记为用户编辑，影响同步版本判断

- 位置：[store.dart](../lib/data/res/store.dart) 第 189–190 行；[setting.dart](../lib/data/store/setting.dart) 第 127 行；[sync.dart](../lib/core/sync.dart) 第 256–264 行。
- 触发条件：设置中 locale 为空且 lastVer、introVer 均为 0，例如缺少这些标记的旧 Hive 数据导入后，或者首次初始化。
- Hive 导入本身保留原时间戳，但其后的 `setting.locale.put('zh_CN')` 使用普通写入，会记录当前修改时间。`Stores.lastModTime` 和同步的 `localVersionTag` 随之变化，将自动初始化当作本机用户修改。
- 单独运行现有测试 `importing does not present itself as a local edit` 复现：预期最后修改时间为 0，实际为运行时的时间戳。
- 建议：默认值初始化不更新时间戳；判断新安装时同时考虑是否存在导入数据，保留旧安装跟随系统语言的选择。
- 限制：不能将此结论推广为所有旧安装均受影响；有非零版本标记的安装不会进入这个分支。没有实测云端数据被覆盖。

### 3. P2：Monitor 的命令输出上限没有限制读取时的内存占用

- 位置：[exec.rs](../monitor/src/api/exec.rs) 第 199–220 行。
- `wait_with_output()` 将 stdout、stderr 全部读入内存，进程结束后才调用 `cap()` 截断。配置的 `max_output_bytes` 约束返回内容，没有约束过程中保留的内容。
- 影响：大量输出的命令仍可能使 Monitor 内存显著增长；多个执行请求会放大占用。即使最终响应只有设定的字节数，之前的大缓冲区已经分配。
- 建议：并发消费 stdin/stdout/stderr，逐块读取时只保留配置范围内的输出，超出部分丢弃或按明确策略终止进程；保持超时和 truncated 标记。
- 验证方式：代码路径确认。没有进行大内存压力测试，也没有声称已复现 OOM。

### 4. P2：Windows 自定义命令终止失败后会进入无界等待

- 位置：[script.rs](../crates/sbm_parser/src/script.rs) 第 992–994 行。
- 五秒截止时间到达后执行 `taskkill /T /F`，随后无条件调用 `$p.WaitForExit()`，没有处理终止失败。
- 当前受限 Windows 环境中，`taskkill` 返回 `Access denied`、退出码 1。独立实验中，2 秒截止时间后仍等到 8 秒命令自然结束；现有 Rust 测试中的 30 秒脚本也输出了 `late`，未被五秒上限终止。
- 建议：检查终止结果，为退出等待设置第二个有限上限；失败时返回明确状态，并在支持的权限环境中验证进程树终止。不能只是继续等待。
- 限制：拒绝终止来自当前执行权限；并非所有 Windows 主机都会失败。确认的代码问题是终止失败后的处理路径缺少边界。

## 测试与维护问题

1. **签名测试文件缺少换行保护。** Windows checkout 把 `test/fixtures/rootfs_manifest/signed.json` 转为 CRLF，导致 7 项签名/缓存测试失败。原始 CRLF 字节验证失败，测试中仅在内存恢复 LF 后用同一签名验证通过。建议通过 `.gitattributes` 固定被签名文件的原始字节；不能重新生成签名来掩盖失败。未修改原文件，此项不能解释为生产远程下载验证有缺陷。
2. **首页标签测试仍针对旧控件。** `test/server_tag_switcher_test.dart` 的 2 项测试查找 `SessionSwitcherLabel` 下拉按钮；新首页在 `warm_dashboard.dart:234` 使用可直接选择的标签 chips。应更新测试，验证新交互下的标签筛选行为，而不是简单删除断言。
3. **跨平台测试需要环境分支。** Flutter 失败中 18 项涉及符号链接权限、POSIX 工具等，9 项密钥互操作测试涉及临时目录访问被拒绝。Monitor 的 `exec_api` 超时测试在 Windows 使用 `timeout /t`，这个命令在重定向输入下提前退出，不能充当可靠的阻塞命令。应使用可在目标平台稳定阻塞的测试程序，并为权限前置条件设置明确检查。
4. **一个低优先级静态警告。** `warm_dashboard.dart:1037` 的 `_WarmPill.iconSize` 可选参数从未被传入。可以简化接口；没有发现因此造成的运行错误。

## 实际验证结果

| 检查 | 结果 |
| --- | --- |
| Dart analyze lib/test/hook | 无编译错误，1 个未使用参数警告 |
| Flutter 全量测试 | 2691 通过、34 跳过、37 失败 |
| Flutter 失败分类 | 1 项迁移时间戳、7 项签名文件换行、2 项旧 UI 断言、27 项平台/权限环境问题 |
| Rust FFI 本地构建 | 成功 |
| Monitor 单元测试 | 158 通过 |
| Monitor 选定集成测试 | custom_cmds 4、external_probes 3、fs_api 4、terminal_ws 28 通过；terminal_ws 1 跳过 |
| Monitor 全量测试尝试 | 执行到 exec_api：16 通过、上述 Windows timeout 测试失败；未将其后的测试算作通过 |
| sbm_native | 6 单元测试、8 合约测试通过，SSH e2e 1 跳过 |
| sbm_parser | 92 单元测试通过；script_compat 43 通过、Windows 自定义命令超时 1 失败 |
| 独立复核 | 检测断开、迁移时间戳分别复现；LF 签名验证通过；Windows 超时失败路径复现 |

完整 Rust workspace 首次执行受到并行原生构建产物冲突影响，因此以上采用串行复核结果，不报告 workspace 全部通过。Monitor 前端和 webui 缺少已安装依赖，本轮未执行其构建。没有执行 iOS/Android 真机测试、真实 SSH/云同步端到端测试或 IPA 编译。

本轮没有修改生产代码。复现脚本与日志位于被忽略的 `.tools/review-*`，保留现有未提交工作；测试生成的设计预览图片可能重新写出。
