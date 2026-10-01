# 五页移动端 UI 验收

日期：2026-10-01。范围：编辑服务器、服务器详情、进程、服务、端口映射。按用户选定第一套方案修改现有 Flutter 页面，继续使用原有数据、权限、校验、存储和操作。

## Findings

当前五页没有未解决的 P0、P1、P2 布局或核心交互问题。

- [P1，已修正] 深色主题继承浅色背景和文字，部分卡片文字不可读。`WarmTheme.dark()` 改为完整深色前景、背景、导航及组件配色。正文、辅助文字与列表标题在页面及卡片背景上的对比度测试达到 4.5:1。
- [P2，已修正] 初次编辑页把自动连接与高级选项推到首屏之外。缩短协议行、并排端口与用户、空标签入口移入高级选项；保存固定在安全区。390 × 844 首屏现在可见认证、自动连接、高级选项及保存。
- [P2，已修正] 详情重复信息及展开的硬件明细挤占图表。顶部精简为系统、主机、运行时间摘要；其余信息和 CPU 型号明细可展开。默认首屏同时显示 CPU 与内存图表，工具菜单不遮挡图表。
- [P2，已修正] 小屏大字体下映射弹窗选项与字段标签过窄。移动端模式选项可换行；320 像素或大字体时地址字段改纵向排列，已复查实际添加并保存 SOCKS5 规则。
- [P3，可接受] 原生控件、系统字体和生成图的笔画有差异。进程使用通用终端图标，服务使用现有类型图标；未增加仅对截图中的程序名有效的品牌资源。服务筛选继续使用文字宽度的原有 FilterChip。图表保留实际历史与现有坐标，不伪造源图中的五小时数据或走势。

扩展检查发现两个未改动的桌面设置导航测试失败：`test/settings_pane_nav_test.dart` 的 `a pushed page goes when another section is picked` 与 `and the declarative pages themselves are not popped`，仍查找已改版旧菜单中的 AI 项。本次未修改设置页或该测试；不宣称全仓库测试通过。日志：`.tools/five-pages-final-tests.log`。

## Comparison target

Source visual truth：用户选择的五页方案图，1962 × 802。

- 原图：`C:/Users/17641/.codex/generated_images/01a0f2ee-b489-7f43-9e9d-4752ff0ab854/exec-745523cc-766b-450f-b3d9-e9fcefcfd991.png`
- 工作区副本：`design-qa/server-pages-reference.png`
- 用户选择附件：`C:/Users/17641/AppData/Local/Temp/codex-clipboard-019fecd4-3600-4a2c-9423-b5864f6208d7.png`

源图五个面板等比例放入 390 × 844 对比画布，未拉伸。实际 Flutter 截图为 390 × 844、DPR 1，像素与逻辑尺寸一致，无 CSS。包含真实页面及应用相同底部导航配置的测试壳，不包含伪造 iOS 状态栏。源图面板略短，此比例差异不作为逐像素一致的证明。

状态：中文、浅色、服务器 123、在线、SSH 开启、Monitor 关闭、密码认证；进程与服务加载、映射为空。采用内存 SQLite、真实控件与进程解析器，注入服务器快照及执行结果。夹具的数值、进程数量、图表走势与源图不同；不访问真实 SSH，不写生产数据库。

## Evidence and comparison history

实现总览：`design-qa/server-pages-board.png`，1950 × 844。小屏总览：`server-pages-board-large.png`，每页 320 × 740、文字缩放 1.5。深色总览：`server-pages-board-dark.png`，每页 390 × 844。

已打开源图与实现放在同一图像输入中的五个逐页对比：`design-qa/server-pages-compare-editor.png`、`server-pages-compare-detail.png`、`server-pages-compare-process.png`、`server-pages-compare-services.png`、`server-pages-compare-forward.png`。各 790 × 844，左为源图、右为实际渲染。

已打开局部放大比较：`design-qa/server-pages-focus-editor.png`（认证与保存）、`server-pages-focus-process.png`（表头、数字、行与菜单）、`server-pages-focus-services.png`（筛选、状态、标签）。只裁剪放大证据，不修改实现截图。

交互证据：`design-qa/server-pages-tools.png`、`server-pages-process-details.png`、`server-pages-services-user.png`、`server-pages-forward-add.png`、`server-pages-forward-add-large.png`、`server-pages-forward-saved.png`。

1. 初次比较记录位于 `design-qa/server-pages-initial/`。编辑页首屏与详情图表问题使验收保持 blocked。
2. 修正分组密度及详情展开方式，重新渲染并逐页对比，确认首屏信息与图表位置。截图测试加载中文、Material 及现有图标字体，初始化本地 Rust 解析库，避免缺字体、缺库的测试环境误判。
3. 深色与小屏复查发现对比度及映射标签问题，修正主题和字段排列后重新捕获全部五页及弹窗。
4. 最终打开修正后的逐页对比、局部细节、深色/小屏总览和小屏弹窗，主要文字可读，无横向溢出或固定控件遮挡。

## Required fidelity surfaces

- 字体：沿用应用字体层级，标题 20、正文 14–16、辅助文字 12。测试加载微软雅黑；手机保留平台字体设置。检查换行、1.5 倍字体和缺字；生产与 Windows 栅格化差异列为 P3。
- 间距与布局：主体左右 18，主要组间距 12–14；三项指标并排，小屏大字体改纵向；服务使用整体容器及分隔线。底部导航 76，主要按钮至少 48，工具菜单触摸区域至少 44。可滚动查看大字体超出首屏的内容。
- 颜色：浅色沿用 cream/peach/copper WarmTheme token；选中认证与保存为铜色。状态同时显示文字。深色使用完整语义 token，并检查主要文字对比度。
- 图像与资源：使用现有 Material/MingCute 图标库和原生控件；没有整页图片覆盖功能。方案无需复制照片或插画。品牌图标与装饰箭头差异已列为 P3。实际截图未经美化，拼图仅展示。
- 文案与内容：新增 19 个本地化键，维护英文、简体、繁体并生成其他语言回退。私钥使用现有本地化。映射说明正确区分本地、远程、SOCKS5，不承诺自动转发全部流量；保留数据、卡片配置及原有操作。

## Validation

相关回归 133 项通过：`.tools/five-pages-target-tests.log`。包括新增 19 项，以及服务器编辑、详情、进程解析、服务管理、映射存储/状态、设置折叠、首页、终端和动画回归。额外旧桌面设置测试失败单独记录。

静态检查范围为本次主题、五页、公共控件和截图测试：`.tools/five-pages-final-analyze.log`。结果 No issues found。

操作验证：修改主机后保存并读取 SQLite 校验密码保留；双协议保留输入；工具菜单保留允许且配置的入口；进程详情及 PID 排序；服务用户作用域筛选；新增 SOCKS5 并读取持久化规则。截图过程检查 Flutter 异常。

边界：尚未验证真机软件键盘、iOS/Android 系统字体或真实网络操作；未执行真实进程终止、服务启停；本次未编译或上传新 IPA。

## Implementation checklist

- [x] 五页接入原有功能。
- [x] 逐页与局部对比，修正 P1/P2 后重拍复查。
- [x] 小屏、大字体、深色和弹窗检查。
- [x] 相关回归与静态检查。
- [x] 记录可接受差异、额外失败与真机验证边界。

final result: passed
