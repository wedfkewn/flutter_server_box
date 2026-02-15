# UI Modernization: Rounded Card Style

## Why
The current UI lacks visual appeal and modern interaction feedback. The user specifically requested a "rounded card style" and "modern interactions" to improve the overall look and feel of the Android app.

## What Changes
-   **Global Theme Configuration**:
    -   Update `lib/app.dart` to include a global `CardTheme` in both light and dark `ThemeData`.
    -   Set `CardTheme.shape` to `RoundedRectangleBorder` with a larger border radius (e.g., 16px) to achieve the requested "rounded" look.
    -   Set `CardTheme.elevation` and `shadowColor` to enhance depth.
    -   Set `CardTheme.clipBehavior` to `Clip.antiAlias` to ensure content respects the rounded corners.
-   **Component Updates**:
    -   Ensure `CardX` (from `fl_lib`) and other card-like widgets respect the global `CardTheme`.
    -   (Optional) If `CardX` overrides theme values, wrap it or adjust usage where necessary to enforce consistency.

## Impact
-   **Affected Capabilities**:
    -   All screens using `CardX` or standard `Card` widgets (Server list, Settings, Snippets, etc.) will automatically adopt the new rounded style.
-   **Affected Code**:
    -   `lib/app.dart`: Main entry point for theme configuration.

## ADDED Requirements
### Requirement: Rounded Card Visuals
The system SHALL display all cards with a consistent border radius of 16 logical pixels.
-   **Scenario: Server List**
    -   **WHEN** the user views the server list.
    -   **THEN** each server item is displayed in a card with rounded corners.
-   **Scenario: Settings Page**
    -   **WHEN** the user views settings entries.
    -   **THEN** setting groups are displayed in rounded cards.

### Requirement: Modern Interaction
The system SHALL provide visual feedback on interactions.
-   **Scenario: Card Touch**
    -   **WHEN** the user taps on a card (e.g., server item).
    -   **THEN** the ripple effect (InkWell) must be clipped to the card's rounded borders.

## MODIFIED Requirements
### Requirement: App Theme
**Modified**: `_buildApp` in `lib/app.dart`
-   **Old**: No explicit `CardTheme`.
-   **New**: Explicit `CardTheme` with `shape`, `elevation`, and `clipBehavior`.
