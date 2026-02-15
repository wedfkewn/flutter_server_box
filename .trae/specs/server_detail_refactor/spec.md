# Server Detail Page Refactor Spec

## Why
The current server detail page suffers from layout overflow issues (top overflow) and crowded UI. The navigation is cumbersome, requiring users to reach the top for critical functions like Terminal and SFTP. A modern, gesture-driven interface with a floating bottom navigation bar will improve usability and visual appeal.

## What Changes
- **Layout Structure**: Replace the single scrollable column with a `PageView` containing distinct functional tabs.
- **Navigation**:
  - Remove top function buttons (`ServerFuncBtns`).
  - Add a **Floating Bottom Navigation Bar** (Capsule style) with shadow and rounded corners.
  - Implement **Global Swipe Gestures** to switch between tabs (Dashboard -> Terminal -> SFTP -> Docker -> Snippet).
- **New "Dashboard" Tab**:
  - Create a dedicated "Info/Status" tab as the default view.
  - Move existing CPU, Memory, Disk, and System info widgets to this tab.
- **Integration**:
  - Embed `SSHPage` (Terminal), `SftpPage`, `ContainerPage`, and `SnippetListPage` as tabs within the `PageView`.
  - Ensure smooth transitions between tabs.
  - Sync bottom navigation indicator with page swipes.

## Impact
- **Affected Specs**: Server Management, Navigation.
- **Affected Code**:
  - `lib/view/page/server/detail/view.dart`: Major refactor to use `PageView` and `Stack`.
  - `lib/view/widget/server_func_btns.dart`: Will be removed or deprecated in this context.
  - New file: `lib/view/page/server/detail/dashboard.dart` (for the status dashboard).
  - New file: `lib/view/widget/floating_bottom_nav.dart` (for the new navigation bar).

## ADDED Requirements
### Requirement: Floating Bottom Navigation
The system SHALL provide a floating navigation bar at the bottom of the screen.
- **Style**: Capsule shape, floated above the content, with shadow.
- **Items**: Info, Terminal, SFTP, Docker, Snippet.
- **Behavior**: Tapping an item switches the `PageView` to the corresponding tab.

### Requirement: Dashboard Tab
The system SHALL display server status metrics (CPU, Memory, Disk, OS info) in a dedicated scrollable tab.

### Requirement: Global Swipe Gestures
The system SHALL allow users to swipe left/right anywhere on the screen (except where gestures are consumed by children like Terminal) to switch tabs.

## MODIFIED Requirements
### Requirement: Server Detail Page Layout
**Old**: Single column with widgets and function buttons at the top.
**New**: `Stack` containing `PageView` (content) and `FloatingBottomNavBar` (navigation).
**Reason**: To solve overflow issues and improve one-handed usability.

## REMOVED Requirements
### Requirement: Top Function Buttons
**Reason**: Replaced by Bottom Navigation for better reachability.
