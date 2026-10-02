# Mobile UI system

The UI uses a cool gray canvas, white grouped cards, a restrained blue accent,
and system typography. Existing `WarmTheme` names are retained to avoid changing
business-facing APIs. Dark mode and user-selected themes remain available.

## Official integrations

- [ForUI](https://github.com/duobaseio/forui), pinned to 0.26.0:
  `AppUiScope` maps the existing Material theme into `FThemeData`, including
  typography and touch sizing. `AppCard`, `AppButton`, and `AppPageBody` use
  `FCard`, `FButton`, and `FScaffold`. The server editor uses managed
  `FTextField` controls with the existing controllers, focus nodes, and save
  callbacks. Card padding is applied through the official card builder API.
- [FL Chart](https://github.com/imaNNeo/fl_chart): the existing shared history
  renderer supplies curved lines, restrained gradient fills, animated updates,
  and touch tooltips with measured values and sample timestamps. CPU, memory,
  network, disk, and other history panels share this renderer. Missing samples
  remain gaps; irregular sampling retains its real elapsed-time spacing.
- [flutter_animate](https://github.com/gskinner/flutter_animate), pinned to
  4.5.2: card/chart entrances fade once over 180 ms; measurement updates fade
  over 140 ms. There are no repeating effects, blur, or animated terminal output.
  Reduced-motion settings bypass these effects and disable chart transitions.

ForUI 0.26 requires Flutter 3.47 and Dart 3.13. The app's minimum Flutter version
now reflects this; the local toolchain and CI both use Flutter 3.47.1. The root
package retains its existing Dart 3.11 library language version so that existing
Freezed output remains valid; ForUI uses its own Dart 3.13 library language
version. This avoids unrelated regeneration of the app's models.

## Scope and verification

Shared components cover the dashboard, server detail cards, server editor,
settings categories/groups, and terminal connection drawer. Material navigation,
dialogs, SSH sessions, transports, credentials, providers, stores, and actions
retain their existing behavior. No backend changes are needed for this UI work.

Widget regression checks cover form saving and controller ownership, chart gaps
and tooltips, settings persistence/navigation/reordering, lazy list scrolling,
dark mode, landscape, 320-pixel screens, and enlarged text. Animation checks
verify that monitoring refreshes preserve focus and do not replay entrances,
and that reduced motion displays values immediately. Screenshots in
`design-qa/` use fixture data rather than live server measurements.

Real-device iOS frame timing and IPA installation are not verified by these
Windows-hosted widget tests.
# 主题切换与种子色

- 应用使用已保存的种子色生成浅色／深色强调色；系统动态色可用且启用时使用系统调色板。中性浅色页面背景保持一致。
- `ThemeReveal` 在选择弹窗退出后捕获一次旧画面，新主题在右上角通过圆形扩散显示，时长 420ms。旧画面只在内存中保留，不写磁盘；动画结束、窗口尺寸变化或减少动态效果时释放。
- 按 [Flutter 官方 CustomClipper](https://api.flutter.dev/flutter/rendering/CustomClipper-class.html) 的 `reclip` 方式更新裁剪，动画期间不逐帧重建导航、终端或监控页面。关闭 MaterialApp 与 ForUI 的并行主题插值，缓存主题和 ForUI 配置；截图纹理限制在最多约 200 万像素。
- 系统“减少动态效果”启用时立即切换。AMOLED 保留原控件文字、圆角和布局，仅调整背景，避免文字样式插值冲突。
- 手机端声明式 `WarmPage` 路由从当前 `settings` 读取页面内容，与 Flutter `MaterialPage` 一致。避免同一页面 key 更新后继续引用首次创建的背景，导致主题切换后背景和卡片明暗不一致。回归测试见 `test/warm_page_theme_test.dart`。
- 验证：`test/theme_reveal_test.dart`、`test/app_theme_test.dart` 覆盖扩散方向、页面重建次数、输入状态、快速切换、尺寸变化、弹窗退出与实际种子色生效；真机 GPU 帧耗时需要用 release/profile 版本另外测量。

## 发行版与程序图标

- 本地图标保留源素材颜色，以固定大小的中性底板适配浅色和深色界面。资源来源、不可变提交与 SHA256 见 `assets/brands/manifest.json`；许可说明见同目录 README 和 LICENSE 文件。
- 首页与详情使用发行版图标；进程和服务列表按可执行文件名或 service/socket 单元识别程序，不扫描命令参数。未知程序使用原通用图标，业务命令和采集协议保持原样。
- 设置中的“程序图标”提供全局进程/服务独立映射，可选择内置图标或 HTTPS 图片。内置素材离线可用；自定义图片按 URL 缓存，最多 64 项、每项 512 KiB，失败时保持尺寸并显示通用图标。
- v24 迁移仅首次开启图标，此后保留用户开关。自定义规则和开关参与备份，迁移标记仅留在本机。旧发行版 URL 与名称映射仍然兼容。

The language selector is a centered floating dialog with bounded height and width. It searches native names, Chinese/English names and locale codes; choices stay in a fixed order while selecting. Done commits through the existing settings callback, while closing or tapping the backdrop cancels. Keyboard insets shrink the scrolling list, and compact viewports omit the current-language hint.

Other app dialogs now use the app-owned AppDialogX adapter and AppFloatingDialog shell. This keeps the fl_lib submodule unchanged and makes the presentation reproducible in CI. The shell uses 28-pixel corners, bounded width/height, scrolling content, theme-derived colors and a close button only on dismissible routes. Selection dialogs use aligned rows with checkmarks; lists longer than eight options add search. Single selections still return immediately, while multiple selections, tagged choices, forms, confirmations and import flows retain their existing result contracts. Loading and SSH authentication retain their dismissal restrictions. The underlying widget/theme support also applies to library-owned dialogs; OS file pickers remain native.

Regression coverage: floating_dialog_test.dart exercises selection/search, cancel/confirm results, supplied-action immutability, locked dialogs, narrow screens, large text and keyboard/landscape layout. Related settings, external checks, SSH authentication/key unlock and server-import tests verify integration. Preview captures in design-qa/floating-dialogs use fixture content. iPhone release performance and installation still need device verification.
