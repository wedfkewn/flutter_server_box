# 国旗不显示修复计划

## 现象
服务器卡片红框区域里，IP 地理信息的“国旗/国家”没有展示（整条信息可能直接消失）。

## 根因定位（已确认）
1. **UI 判断逻辑写反，导致数据到达也会 `shrink` 掉**  
   当前 `IpLocationQuery` 在 `AsyncValue.data` 分支里，真正“匹配当前 IP 的数据”反而走到 `return SizedBox.shrink()`，因此看起来像“没有国旗/没有结果”。  
   相关代码位置：[ip_location_query.dart](file:///d:/tare%20project/flutter_server_box-1/lib/view/widget/ip_location_query.dart#L45-L76)

2. **`ipInfoProvider` 是单例 AsyncNotifier，只能保存一份结果**  
   服务器列表存在多张卡片，每张卡片都会触发一次 fetch；单例 provider 会被反复覆盖，导致其它卡片显示错位、闪烁或被隐藏。  
   相关代码位置：[ip_info.dart](file:///d:/tare%20project/flutter_server_box-1/lib/data/provider/ip_info.dart)

3. **国旗图片外链域名可能在部分网络环境不可达**  
   当前使用 `https://flagcdn.com/...`，在国内网络/部分 ROM 环境可能被拦截或解析异常；即使逻辑正确，也可能加载失败。  
   相关代码位置：[ip_location_query.dart](file:///d:/tare%20project/flutter_server_box-1/lib/view/widget/ip_location_query.dart#L130-L143)

## 目标
在红框区域稳定展示“国家（国旗）+ 国家码/城市”等信息，且多服务器卡片同时存在时不互相覆盖。

## 计划变更

### 1) 先修 UI 逻辑（P0，保证“能显示出来”）
- 调整 `IpLocationQuery` 的 `AsyncValue.data` 分支判断：
  - “数据不为空且 IP 匹配”时渲染结果行（国旗 + 文本）。
  - “不匹配/为空”时渲染占位（建议显示一个很小的加载/空态占位，避免整行消失）。
- 同时清理当前文件内的调试/解释性长注释，保持项目风格（项目约束：不额外添加注释）。

### 2) 把 Provider 改为按 IP 隔离（P1，解决多卡片竞态）
- 将 `ipInfoProvider` 从“单例”改为“按 IP 的 family provider”：
  - 方案 A（推荐）：`FutureProvider.family<IpInfo?, String>` 或 `AsyncNotifierProviderFamily`
  - UI 侧改为 `ref.watch(ipInfoProvider(widget.ip))`，刷新则 `ref.invalidate(ipInfoProvider(widget.ip))` 或调用对应 notifier。
- 缓存与限流策略：
  - 缓存维持“每 IP TTL 5 分钟”
  - 限流维持“全局 1 RPS”（用共享的队列/互斥，避免列表同时触发 N 个请求）

### 3) 国旗展示策略升级（P2，保证“各网络环境可见”）
按用户诉求优先展示“emoji 形式”，同时提供稳健兜底：
- **优先：Emoji 国旗**  
  - 用国家码转区域旗帜序列（如 `CN -> 🇨🇳`）。
  - 配置 `TextStyle(fontFamilyFallback: [...])`（如 `NotoColorEmoji/Segoe UI Emoji/Apple Color Emoji`）提升命中率。
- **兜底：本地图片国旗（最稳）**  
  - 若 Emoji 机型/系统不支持（国产 ROM 常见），改用 assets 国旗图（`WidgetSpan`/直接 Image 展示），保证一定可见。
  - 如暂不引入全量国旗 assets，可先做“emoji + 国家码（CN/US）”双显，至少能识别国家。
- **不再依赖单一外链域名**（可选）  
  - 若仍使用网络图片，提供多源 fallback（flagcdn 失败切换其它源），并保留缓存。

## 验证方式
- 功能验证：
  - 服务器列表存在多张卡片时，每张卡片展示自己的国家信息，不互相覆盖/闪烁。
  - 网络异常时有明确错误态，占位不消失，点击可重试。
- 兼容验证：
  - 在至少 2 个机型/模拟器上验证 emoji 国旗是否可见；不可见时验证兜底（国家码/图片）可见。
- 自动化验证：
  - 增加单元测试：国家码到 emoji 的转换（如 `CN -> 🇨🇳`）。
  - 增加 provider 测试：同一 IP 5 分钟内命中缓存、全局限流生效。

