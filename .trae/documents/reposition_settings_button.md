# Plan: Reposition Settings Button

The goal is to move the settings button from the top-left corner of the "ServerBox" page to the bottom navigation area, ensuring consistency with the existing UI.

## Analysis
- **Current Location**: The settings button is located in the top-left corner of the `ServerPage` (`_TopBar` widget), combined with the app title "ServerBox".
- **Target Location**: The bottom navigation bar (`HomePage`).
- **Implementation**: 
  - The bottom navigation bar is driven by the `AppTab` enum and `Stores.setting.homeTabs`.
  - The `AppTab` enum already has a commented-out `settings` entry.
  - Enabling this entry will allow "Settings" to appear as a tab in the bottom navigation bar.
  - The `SettingsPage` is a full page with a `Scaffold`, which is compatible with the `PageView` structure in `HomePage`.

## Steps

1.  **Update Data Model (`AppTab`)**:
    -   Modify `lib/data/model/app/tab.dart` to uncomment and enable the `settings` tab.
    -   Assign `@HiveField(4)` to `settings` to maintain backward compatibility.
    -   Uncomment the `page`, `navDestination`, and `navRailDestination` mappings for `settings`.
    -   Ensure `SettingsPage` is imported.

2.  **Update UI Components (`TopBar`)**:
    -   Modify `lib/view/page/server/tab/top_bar.dart` to remove the settings button interaction and icon.
    -   Retain the "ServerBox" title as a static text label.

3.  **Regenerate Code**:
    -   Run `dart run build_runner build --delete-conflicting-outputs` to update the Hive adapter for `AppTab`.

4.  **Verification**:
    -   Verify that the "ServerBox" title remains at the top left but is no longer clickable and has no settings icon.
    -   Verify that a new "Settings" tab appears in the bottom navigation bar.
    -   Verify that clicking the "Settings" tab navigates to the settings page correctly.

## Files to Modify
-   `lib/data/model/app/tab.dart`
-   `lib/view/page/server/tab/top_bar.dart`

## Commands to Run
-   `dart run build_runner build --delete-conflicting-outputs`
