# 开源许可声明功能规格

## 为什么
用户需要在设置页面查看应用程序的开源许可信息，了解该应用是 ServerBox 的派生版本，基于 GNU AGPL v3.0 许可证发布。这有助于提高透明度并满足开源许可证的要求。

## 变更内容
- 在设置页面的 App 标签下添加一个新的 "开源许可" 设置项
- 点击后弹出对话框显示许可声明内容
- 提供查看源代码和许可证全文的链接按钮
- 添加多语言支持（中文、英文等）

## 影响
- 受影响的文件：
  - `lib/view/page/setting/entries/app.dart` - 添加设置项入口
  - `lib/l10n/app_zh.arb` - 添加中文本地化字符串
  - `lib/l10n/app_en.arb` - 添加英文本地化字符串
  - `lib/l10n/app_zh_tw.arb` - 添加繁体中文本地化字符串
  - `lib/generated/l10n/l10n.dart` - 生成本地化代码
  - `lib/generated/l10n/l10n_*.dart` - 生成本地化实现

## 新增需求

### 需求：开源许可声明功能
系统应在设置页面提供一个入口，允许用户查看应用程序的开源许可声明。

#### 场景：显示设置项
- **当** 用户打开设置页面的 App 标签
- **那么** 应该看到一个 "开源许可" 设置项
- **并且** 设置项显示主标题 "开源许可" 和副标题 "基于 ServerBox (AGPL-3.0)"
- **并且** 设置项左侧显示证书/文档图标

#### 场景：打开许可声明对话框
- **当** 用户点击 "开源许可" 设置项
- **那么** 弹出一个对话框显示许可声明内容
- **并且** 对话框标题为 "关于 & 许可"
- **并且** 内容包含：
  - 本程序为 ServerBox 的派生版本声明
  - GNU AGPL v3.0 许可证条款说明
  - 版权所有：© 2024 lollipopkit & all contributors
  - 项目性质：自由软件 (Free Software)
  - 分发条件：必须在相同协议下开放源代码
  - 免责声明：本程序不附带任何担保

#### 场景：操作按钮
- **当** 许可声明对话框显示时
- **那么** 底部应显示三个操作按钮：
  - [查看源代码] - 打开 GitHub 仓库链接
  - [许可证全文] - 打开 AGPL-3.0 许可证全文链接
  - [关闭] - 关闭对话框

## 本地化需求
需要添加以下本地化字符串：
- `openSourceLicense` - "开源许可" / "Open Source License"
- `openSourceLicenseSubtitle` - "基于 ServerBox (AGPL-3.0)" / "Based on ServerBox (AGPL-3.0)"
- `aboutAndLicense` - "关于 & 许可" / "About & License"
- `licenseContent` - 许可声明正文
- `viewSourceCode` - "查看源代码" / "View Source Code"
- `fullLicenseText` - "许可证全文" / "Full License Text"
