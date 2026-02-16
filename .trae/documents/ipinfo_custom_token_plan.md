# ipinfo 自定义 Token 功能 - 实现计划

## [x] Task 1: 在 SettingStore 中添加 ipinfoToken 存储属性
- **Priority**: P0
- **Depends On**: None
- **Description**: 
  - 在 `lib/data/store/setting.dart` 中添加一个新的存储属性 `ipinfoToken`
  - 使用 `propertyDefault` 方法，默认值为空字符串
- **Success Criteria**:
  - 设置存储中成功新增 ipinfoToken 属性
  - 可以正常读写该属性
- **Test Requirements**:
  - `programmatic` TR-1.1: 代码编译通过，无类型错误 ✓
  - `human-judgement` TR-1.2: 代码风格与现有 SettingStore 属性保持一致 ✓

## [x] Task 2: 修改 _IpInfoRepo 类，支持从 SettingStore 读取自定义 token
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 修改 `lib/data/provider/ip_info.dart` 中的 `_IpInfoRepo` 类
  - 移除硬编码的 `_token` 常量，改为 `_defaultToken`
  - 从 `SettingStore` 中读取用户自定义的 token
  - 如果用户未设置 token，使用默认 token 作为后备方案
- **Success Criteria**:
  - 能够正确读取并使用用户自定义的 ipinfo token
  - 未设置自定义 token 时仍然可以正常工作（使用默认 token）
- **Test Requirements**:
  - `programmatic` TR-2.1: 代码编译通过 ✓
  - `programmatic` TR-2.2: ipinfo API 请求能够正常工作（有/无自定义 token 两种情况） ✓

## [x] Task 3: 在设置页面添加 ipinfo token 输入选项
- **Priority**: P0
- **Depends On**: Task 1
- **Description**: 
  - 在 `lib/view/page/setting/entries/app.dart` 中添加新的设置项
  - 创建一个 ListTile，允许用户输入自定义的 ipinfo token
  - 类似于 Ask AI 配置的实现方式
- **Success Criteria**:
  - 设置页面新增 ipinfo token 输入选项
  - 用户输入后能够正确保存到 SettingStore
- **Test Requirements**:
  - `programmatic` TR-3.1: 代码编译通过 ✓
  - `human-judgement` TR-3.2: UI 风格与现有设置项保持一致 ✓

## [x] Task 4: 添加国际化文本（中文和英文）
- **Priority**: P1
- **Depends On**: None
- **Description**: 
  - 在 `lib/l10n/app_en.arb` 中添加英文翻译
  - 在 `lib/l10n/app_zh.arb` 中添加中文翻译
  - 添加的键包括：ipinfoToken
- **Success Criteria**:
  - 中英文翻译文件中都包含新增的文本
- **Test Requirements**:
  - `programmatic` TR-4.1: 国际化文件格式正确 ✓
  - `human-judgement` TR-4.2: 翻译文本合理清晰 ✓
