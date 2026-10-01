# 设置页分类展开 UI 验收

日期：2026-10-01。范围：用户选定的第三个设置页方案，直接重构现有 Flutter 设置首页。

## Findings

没有未解决的 P0、P1、P2 问题。

- [P3] 字体使用手机平台字体；Windows 截图加载微软雅黑并使用 Material Icons。字形、字重和抗锯齿与生成图存在轻微差异，iOS/Android 实机字体仍需确认。
- [P3] 子项点击区域至少 44 逻辑像素，比设计图略高，展开面板因此略长。小屏和大字号可滚动，底部导航仍可见。
- 有意保留原有 Home 的 76 像素导航栏和图标配置，未按生成图改动全局导航。截图通过测试壳复用相同 NavigationBar 配置，不代表完整 Home 的导航集成或设备运行结果。
- 页尾按现有关于页使用 BuildData 的真实构建号“ServerBox v1579”，没有硬编码生成图中的版本字符串。
- 该构建在支持 Linux 引擎的平台仍显示原有 Linux (Beta) 入口；截图是在 Windows 渲染，不会隐藏任何平台原有设置。

## Comparison target

Source visual truth:
`C:\Users\17641\.codex\generated_images\01a0f2ee-b489-7f43-9e9d-4752ff0ab854\exec-d49252f1-d170-44bd-b22c-79a8c3179a2a.png`

Implementation:
- `E:\codex project\ssh\design-qa\settings-accordion-expanded.png`
- `E:\codex project\ssh\design-qa\settings-accordion-collapsed.png`
- `E:\codex project\ssh\design-qa\settings-accordion-large-text.png`
- `E:\codex project\ssh\design-qa\settings-accordion-dark.png`

状态：简体中文、浅色主题，连接与终端展开，其他分类收起。视口 390 × 848 逻辑像素，DPR 1；实际截图 390 × 848 像素。源图实际尺寸 850 × 1850 像素；仅在对比图中以等比例缩放/极小边缘裁剪规范到 390 × 848。原始 Flutter 截图没有修改。源图和实现都没有系统状态栏、设备边框或 Home indicator。

## Combined full-view and focused evidence

已直接打开源图、实际 Flutter 截图，并在同一输入中查看左右并排对比。左边是选定方案，右边是实际渲染。

- 全图：`design-qa/settings-accordion-comparison.png`
- 展开面板细节：`design-qa/settings-accordion-focus.png`
- 第一轮对比保留：`design-qa/settings-accordion-comparison-v1.png`

五项保真检查：

1. 字体/排版：设置标题、ServerBox、说明、六个分类和五个连接子项层级清晰。保留系统 CJK 字体，分类加粗，子项常规字重；两倍字号不截断操作文字。
2. 间距/布局：18 像素页边距；收起项直接排列，展开项一块桃色圆角面板，没有子项嵌套卡片。标题分隔线、图标左对齐、上/下箭头及子项右箭头均与选定结构一致。
3. 色彩/tokens：复用 WarmTheme 的奶油色背景、桃色表面和铜色主色，并从当前 ColorScheme 读取深色模式前景/背景。没有新增渐变或阴影。
4. 图标/资产：使用现有 Material Icons 的调色盘、监控、终端、文件夹、盾牌、信息和箭头；目标没有需要生成的照片/插图/位图素材。
5. 文案/内容：保留所有真实 SettingsNode 和页面构造器。“终端设置”“已知主机密钥”作为明确的列表名称；加入中英文资源，其余语言使用生成器的英文回退。没有新增虚构设置。

## Comparison history

第一轮：实际渲染中的收起项图标多缩进了 8 像素，且缺少标题下的分隔线；主机密钥入口仍显示旧名称。作为 P2 对齐/文案差异处理，保持 blocked。

修正：收起项水平内边距改为 0，展开项仍保留 8；补充顶部细分隔线；添加“已知主机密钥”的本地化列表名称。

第二轮：重新运行交互测试并捕获相同视口、主题和展开状态，查看新的 full-view 和 focus 对比。上述差异已消除，其余平台字体、真实构建号、原有导航栏和 44 像素点击区域差异为明确的产品约束，没有需要继续修正的 P0/P1/P2。

## Interaction and code validation

11 项相关测试通过：

`flutter test --no-pub --timeout 30s test/settings_accordion_test.dart test/settings_menu_test.dart test/warm_mobile_shell_test.dart`

覆盖：单分类展开、重复点击收起、切换分类、原有页面跳转、工具栏返回、系统返回、返回后保留分类、服务器信息四个开关与真实 SettingStore 读写、桌面分类轨道，以及 320 × 568、568 × 320、两倍文字和深色主题。测试使用内存数据库，不访问真实服务器。

修改范围的 `flutter analyze --no-pub` 无问题；`git diff --check` 通过。

保留原有页面导航，在导航底层也使用相同设置首页，避免过渡动画露出旧列表。删除已不再使用的旧列表组件。

本地 Windows native_toolchain_rust 缓存的依赖路径解析将含空格的路径拆开，已仅在被忽略的 .tools 中修正转义空格解析并重新生成 hook 缓存；生产依赖和 hook 源码没有改动。使用 --no-pub 复用已安装依赖。

验证边界：未启动完整 Windows/iOS/Android 应用；没有设备安装或实机点击结果。视觉证据来自 Flutter Widget 渲染，核心设置交互由 Widget 测试执行。

## Implementation checklist

- [x] 选定第三个方案并查看源图。
- [x] 实现分类就地展开，复用真实功能页面。
- [x] 验证返回、检测开关和响应式布局。
- [x] 实际渲染并合并对比源图，修复 P2 差异。
- [x] 保留平台和桌面行为。

final result: passed
