# 全局页面 Overflow 检测与修复计划

本计划旨在系统性地检测并修复应用中潜在的 UI 溢出 (Overflow) 问题。

## 1. 核心页面分析与修复

### 1.1 服务器管理 (Server)
- [ ] **列表页 (`lib/view/page/server/tab/`)**: 检查服务器卡片 (`card_modern.dart`) 在小屏幕或长文本下的表现。
- [ ] **详情页 (`lib/view/page/server/detail/`)**: 检查 `dashboard.dart` 和 `view.dart` 中的 Grid/Column 布局，确保在不同屏幕尺寸下自适应。
- [ ] **编辑页 (`lib/view/page/server/edit.dart`)**: 检查表单页面在键盘弹出时是否遮挡或溢出 (需确保 `SingleChildScrollView` 包裹)。

### 1.2 SSH 终端与工具 (SSH)
- [ ] **终端页 (`lib/view/page/ssh/page.dart`)**: 检查终端区域与虚拟键盘 (`virt_key.dart`) 的交互，防止键盘弹出导致布局溢出。
- [ ] **AI 助手 (`lib/view/page/ask_ai.dart`)**: 检查对话列表和输入框的布局。

### 1.3 设置页面 (Setting)
- [ ] **设置列表 (`lib/view/page/setting/entry.dart`)**: 确保长列表可滚动。
- [ ] **具体设置项 (`lib/view/page/setting/entries/`)**: 检查各个设置子页面的 Switch/Text 布局，防止文字过长溢出。

### 1.4 容器与存储 (Container & Storage)
- [ ] **容器列表 (`lib/view/page/docker/container.dart`)**: 检查容器状态/名称过长时的显示。
- [ ] **SFTP (`lib/view/page/storage/sftp.dart`)**: 检查文件路径过长和文件列表项的布局。

### 1.5 其他功能页
- [ ] **代码片段 (`lib/view/page/snippet/`)**: 检查列表和编辑页。
- [ ] **密钥管理 (`lib/view/page/private_key/`)**: 检查密钥内容的展示。

## 2. 检测策略

针对每个文件，重点检查以下模式：
1.  **Row 中的 Text**: 是否包裹在 `Expanded` 或 `Flexible` 中，且设置了 `overflow: TextOverflow.ellipsis`。
2.  **Column 中的 List**: 是否使用了 `Expanded` 或 `SizedBox` 限制高度，防止无界高度错误。
3.  **表单页面**: 是否使用了 `SingleChildScrollView` 或 `ListView` 以支持键盘弹出时的滚动。
4.  **固定高度/宽度**: 是否存在硬编码的宽高 (`width: 100`)，可能导致在小屏设备溢出。

## 3. 执行步骤

我们将按模块逐一进行代码审查和修复。
