# Tasks

- [x] Task 1: Create `FloatingBottomNavBar` widget
  - [x] Implement a capsule-shaped container with shadow and rounded corners.
  - [x] Add icons for Info, Terminal, SFTP, Docker, Snippet.
  - [x] Implement selection state and callback for tab switching.
  - [x] Ensure it floats above content (using `Stack`).

- [x] Task 2: Extract `ServerDashboard` widget
  - [x] Create `lib/view/page/server/detail/dashboard.dart`.
  - [x] Move CPU, Memory, Disk, Net, and System Info widget building logic from `view.dart` to `ServerDashboard`.
  - [x] Ensure `ServerDashboard` accepts `ServerState` or `ServerPrivateInfo` as needed.
  - [x] Add a `CustomAppBar` to `ServerDashboard` since `ServerDetailPage` will lose its AppBar.

- [x] Task 3: Refactor `ServerDetailPage` structure
  - [x] Change `ServerDetailPage` body to use a `Stack`.
  - [x] Add `PageView` as the bottom layer of the Stack.
  - [x] Initialize `PageController` and manage state (current index).
  - [x] Add `FloatingBottomNavBar` as the top layer, positioned at the bottom.
  - [x] Implement `onPageChanged` to update nav bar state.
  - [x] Implement nav bar tap to animate `PageView`.

- [x] Task 4: Integrate Functional Tabs
  - [x] Add `ServerDashboard` as the first page.
  - [x] Add `SSHPage` (Terminal) as the second page. Ensure arguments (`SpiRequiredArgs`) are passed correctly.
  - [x] **Refactor `SSHPage`**: Update `lib/view/page/ssh/page/page.dart` to use `LayoutBuilder` instead of fixed `MediaQuery` height for its body, so it fits within the tab area (considering the bottom padding).
  - [x] Add `SftpPage` as the third page.
  - [x] Add `ContainerPage` (Docker) as the fourth page.
  - [x] Add `SnippetListPage` as the fifth page.
  - [x] Wrap tabs in `Padding` (bottom: ~80) to avoid overlap with `FloatingBottomNavBar`.

- [x] Task 5: Cleanup and Overflow Fix
  - [x] Remove `ServerFuncBtns` usage from `ServerDetailPage`.
  - [x] Verify that the "Top Overflow" issue is resolved by the new layout (Dashboard is scrollable).
  - [x] Ensure smooth animations.

# Task Dependencies
- Task 3 depends on Task 1 and Task 2.
- Task 4 depends on Task 3.
