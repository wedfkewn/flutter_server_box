# 添加 System 选项到悬浮工具栏计划

用户希望在服务器详情页的悬浮工具栏中添加一个 "System" 选项，用于展示进程列表。

## 变更文件

1.  **UI 组件**: `lib/view/widget/floating_bottom_nav.dart`
    *   在 Docker 和 Snippet 之间添加 System 图标。
    *   更新 Snippet 的索引。

2.  **页面逻辑**: `lib/view/page/server/detail/view.dart`
    *   导入 `ProcessPage`。
    *   在 `PageView` 中添加 `ProcessPage` 组件。

## 详细步骤

1.  **编辑 `lib/view/widget/floating_bottom_nav.dart`**
    *   在 `_buildItem(context, 2, FontAwesome.docker_brand, 'Docker')` 之后添加 `_buildItem(context, 3, Icons.list_alt, 'System')`。
    *   将 `Snippet` 的索引从 3 改为 4。

2.  **编辑 `lib/view/page/server/detail/view.dart`**
    *   添加 `import 'package:server_box/view/page/process.dart';`。
    *   在 `PageView` 的 `children` 列表中，在 `ContainerPage` (Docker) 之后添加 `ProcessPage(args: widget.args)`。

## 验证

*   确认底部导航栏显示 5 个图标：Dashboard, SFTP, Docker, System, Snippet。
*   确认点击 System 图标能跳转到进程列表页面。
*   确认进程列表页面能正常显示进程信息。
