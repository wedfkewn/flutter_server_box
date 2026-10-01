# 首页服务器数据接入验收

日期：2026-10-01。范围：用户确认的手机首页布局，以及现有 SSH / Monitor 服务器信息和 ChatGPT / Netflix 可访问性接入。

## Findings

- 当前范围没有未解决的 P0、P1 或 P2 布局或数据接入问题。
- [P3] Windows 测试字体不能绘制国家旗帜 emoji；国家代码 CN 和其余中文、英文、图标均可读。手机端使用平台字体，仍需实机确认。
- [P3] Widget 截图只包含 ServerPage 内容，不包含 iOS 状态栏、系统安全区域和 Home 提供的底部导航。底部导航仍由现有 Home 实现提供。

## Comparison target

用户选定的首页设计：

`C:\Users\17641\.codex\generated_images\01a0f2ee-b489-7f43-9e9d-4752ff0ab854\exec-8cbc1968-2693-4319-99ee-6113a4032cb2.png`

实际 Flutter 渲染：

- `design-qa/implementation-dashboard-data.png`：检测开关关闭。
- `design-qa/implementation-dashboard-checks.png`：ChatGPT 可访问、Netflix 不可访问的缓存状态。

截图视口为 393 × 852 逻辑像素，DPR 1，简体中文、浅色主题。截图中的 123、ubuntu、43.138.167.180、腾讯网络信息及 CPU 1% / 内存 36% / 磁盘 45% 均为测试夹具，不是生产默认值或真实联调结果。

## Full-view and focused comparison

已直接查看完整设计图及两张实际渲染图。以内容区 393 像素宽比较，排除设计图的底部设备区域。

- 保留奶油色背景、桃色圆角服务器卡片、铜色操作按钮和三列资源指标。
- 总览保持紧凑，在线/离线计数在列表上方。
- 服务器信息位于卡片标题下方，包含系统、连接地址和网络归属信息；较长字段截断后可在报告中查看。
- 服务检测位于服务器信息与 CPU/内存/磁盘之间，有独立检测报告入口。
- 实际渲染使用 Material 控件的点击区域；报告入口放在各小节标题右侧。生产/测试筛选仅在服务器具有对应标签时出现。
- 专项检查信息标签换行、检测状态颜色、三列指标、CPU 型号和底部操作布局，未发现溢出。Windows 字体及原生控件字形与设计图有轻微差异。

## Data and interaction validation

- 指标读取现有 ServerStatus；缺失观测值显示破折号，不将初始占位数据显示为 0%。
- 国家、组织、域名、ASN、ISP 使用现有 IP 查询及缓存，保留查询授权和显示开关。
- SSH 检测通过服务器上的固定 curl / wget / PowerShell 命令执行；Monitor 通过已存在的专用 service-reachability 接口执行。
- 官网检测区分可访问、不可访问和暂不可用；另显示未开启、未检测和检测中。
- 缓存结果保留既有有效期；新检测等待服务器连接完成。切换端点、凭据、关闭开关及卸载卡片后，旧请求不能更新卡片或写入缓存。
- 检测报告显示独立结果和时间，并可进入现有设置启用检测。
- 官网可访问性不代表 ChatGPT 账号/API 或 Netflix 地区内容解锁。

## Verification evidence

35 个测试通过：

- `test/service_reachability_test.dart`（9）：解析以及实际生成的 Unix / Windows 检测命令的本地模拟响应。
- `test/monitor_service_reachability_test.dart`（8）：专用接口、认证、独立状态、异常响应、429/404 和 401 token 刷新。
- `test/warm_dashboard_data_test.dart`（12）：数据展示、初始占位、开关、连接生命周期、缓存、过期异步响应，以及 320/393 像素宽、1.0/1.3 文字比例。
- `test/warm_mobile_shell_test.dart`、`test/ip_lookup_cache_test.dart`（合计 6）：现有首页交互及 IP 缓存回归。

新增开启检测后的截图断言后，12 个首页数据测试再次通过。修改的生产文件和新增/修改测试通过 Dart 静态分析，结果为 No issues found。格式与 git diff --check 已检查。

Windows 原目录包含空格，第三方原生 hook 的依赖路径解析失败。测试在临时无空格目录运行同一份源代码；修改文件及 pubspec.lock 的 SHA-256 与工作区逐项一致。未修改产品代码以绕过 hook，未安装系统级 Flutter 或开启 Windows 开发者模式。

## Remaining validation

Android / iOS 实机显示及真实服务器联调尚未执行。本次通过范围为首页实现、模拟数据渲染和本地回归验证。

final result: passed
