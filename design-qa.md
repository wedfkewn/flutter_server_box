# 终端第三方案 UI 验收

日期：2026-10-01。范围：现有 Flutter 终端首页及连接后的命令行，移动端为主。

## Findings

没有未解决的 P0、P1、P2 问题。

- [P3] 原生 Material Icons 与生成图的图标笔画存在差异；Windows 渲染加载微软雅黑与 Consolas，手机平台字体仍以系统和用户终端字体设置为准。
- [P3] Windows 支持本机 shell，截图列表末尾因此有“设备”入口；iOS 根据现有能力判断隐藏该入口。Linux (Beta) 及已安装系统保持原有平台条件，没有为了截图删除功能。
- [P3] 源图的当前会话游标为实心，实际打开抽屉后终端失去输入焦点，游标为空心；关闭抽屉恢复会话焦点。
- 截图通过真实 SSHTabPage、SSHPage、TerminalSession 和 Home 相同配置的底部导航测试壳渲染；测试使用 FakeShellBackend 和内存数据库。没有访问真实服务器，也不代表完整 Home 或 iOS/Android 设备运行验证。
- 手机软件键盘、虚拟按键和真实 SSH 重连仍需设备验证。抽屉打开时隐藏虚拟按键并释放输入焦点，收起后恢复原有按键布局；没有改变键位配置。

## Comparison target

Source visual truth：用户选择的第三张方案图。
`C:\Users\17641\.codex\generated_images\01a0f2ee-b489-7f43-9e9d-4752ff0ab854\exec-e166c11e-cf98-4a1a-9b7b-d96bc20d4b77.png`

源图 850 × 1851；对比中仅规范到 390 × 848。实际 Flutter 截图为 390 × 848、DPR 1，未经修改。比较状态：中文、浅色、当前会话 123、连接与会话抽屉展开；192.0.2.10/20 及命令输出仅为测试夹具，不写入生产页面。

Implementation evidence：
- `design-qa/terminal-redesign-expanded.png`
- `design-qa/terminal-redesign-collapsed.png`
- `design-qa/terminal-redesign-picker.png`
- `design-qa/terminal-redesign-large-text.png`：320 × 568，两倍字号。
- `design-qa/terminal-redesign-landscape.png`：568 × 320，列表可滚动。
- `design-qa/terminal-redesign-dark.png`：与真实设置一致的深色主题。

## Combined full-view and focused evidence

已直接打开源图、Flutter 渲染，并查看同一输入中的左右并排全图及抽屉细节。左为选定方案，右为实现。

- 全图：`design-qa/terminal-comparison.png`
- 细节：`design-qa/terminal-focus.png`

五项保真检查：

1. 字体/排版：顶部会话名和地址分层，连接状态与工具菜单右对齐；抽屉标题、区段标题、会话及服务器行保持方案层级。终端字体与字号继续读取用户设置。
2. 间距/布局：上方直接显示命令行，下方为圆角桃色抽屉；只有当前会话使用高亮表面，新建连接是分隔行。竖屏抽屉最高 392 逻辑像素；横屏适当增加抽屉占比，大字号及长列表可滚动。
3. 色彩/tokens：使用现有 WarmTheme 奶油画布、桃色表面、铜色图标和橄榄色连接状态；深色读取 ColorScheme。保留 Home 原有 76 像素导航栏。
4. 图标/资产：复用 Material Icons 终端、服务器、搜索、展开/收起、关闭及更多；目标没有需要生成的位图资产，生产代码无需加载生成图。
5. 文案/内容：会话名、地址、状态和服务器列表均读取现有模型。连接中/已连接/已断开来自实际 SSHPage 生命周期状态；新增中英文资源，其余语言使用生成器回退。

## Comparison history

第一轮发现抽屉里本机入口占据远程服务器行的位置、标题和分隔线间距有偏差；搜索空结果还存在固定高度内容溢出，保持 blocked。

修正：移动端优先排列远程连接，本机入口保留在后；调整页边距、选中行、头部高度、图标及区段分隔线；空结果改为可滚动文本。补充小屏横屏的抽屉高度策略。

最终轮重新捕获相同状态，并打开 full-view、focus、大字号、横屏和深色截图。上述 P2 差异已解决，剩余差异为平台字体、原生图标、真实能力入口及焦点游标等明确约束。

## Interaction and code validation

31 项相关测试通过：

`flutter test --no-pub --timeout 30s test/warm_terminal_test.dart test/ssh_tab_restore_test.dart test/settings_accordion_test.dart test/settings_menu_test.dart test/warm_mobile_shell_test.dart`

最后一次横屏高度与截图主题夹具调整后，终端 10 项再次通过：

`flutter test --no-pub --timeout 30s test/warm_terminal_test.dart`

终端覆盖：展开/收起保留同一个 SSHPage 与 TerminalSession、输入继续到原 shell、名称/地址搜索、空结果保留打开的会话、已结束输出显示已断开、会话切换不结束后台 shell、关闭取消与确认、保存的 tab 状态、工具菜单及历史入口、小屏/两倍字号/横屏/深色、空会话下的真实服务器列表。桌面会话恢复及前次设置与首页测试保持通过。

修改范围静态分析无问题，`git diff --check` 通过。没有重新编译 IPA 或上传这次修改。

前次设置页验收已保存为 `design-qa/settings-accordion-report.md`。

Final result: passed
