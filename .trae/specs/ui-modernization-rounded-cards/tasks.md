# Tasks

- [x] Task 1: Update Global Theme Configuration: Define `CardTheme` in `lib/app.dart`.
  - [x] SubTask 1.1: Add `CardTheme` with `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` to `ThemeData` for light mode.
  - [x] SubTask 1.2: Add `CardTheme` with `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))` to `ThemeData` for dark mode.
  - [x] SubTask 1.3: Ensure `clipBehavior: Clip.antiAlias` is set in `CardTheme` to clip child content (like images or ripples).
  - [x] SubTask 1.4: Adjust elevation/shadow if necessary for better depth.

- [x] Task 2: Verify and Adjust Components: Ensure `CardX` and other widgets pick up the new theme.
  - [x] SubTask 2.1: Check if `CardX` uses `Theme.of(context).cardTheme`. If not, create a wrapper or modify usage where necessary (since `CardX` is external).
  - [x] SubTask 2.2: Verify list items (e.g., in Settings, Server list) respect the new border radius.
  - [x] SubTask 2.3: Verify ripple effects (InkWell) are clipped correctly.

- [x] Task 3: Enhance Visual Polish: Add spacing/padding where needed.
  - [x] SubTask 3.1: Check if content padding inside cards needs adjustment due to rounded corners.
  - [x] SubTask 3.2: Verify layout on different screen sizes (though mostly handled by Flutter layout).

# Task Dependencies
- Task 2 depends on Task 1.
- Task 3 depends on Task 2.
