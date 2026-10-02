# Mobile UI system

The UI uses a cool gray canvas, white grouped cards, a restrained blue accent,
and system typography. Existing `WarmTheme` names are retained to avoid changing
business-facing APIs. Dark mode and user-selected themes remain available.

## Official integrations

- [ForUI](https://github.com/duobaseio/forui), pinned to 0.26.0:
  `AppUiScope` maps the existing Material theme into `FThemeData`, including
  typography and touch sizing. `AppCard`, `AppButton`, and `AppPageBody` use
  `FCard`, `FButton`, and `FScaffold`. The server editor uses managed
  `FTextField` controls with the existing controllers, focus nodes, and save
  callbacks. Card padding is applied through the official card builder API.
- [FL Chart](https://github.com/imaNNeo/fl_chart): the existing shared history
  renderer supplies curved lines, restrained gradient fills, animated updates,
  and touch tooltips with measured values and sample timestamps. CPU, memory,
  network, disk, and other history panels share this renderer. Missing samples
  remain gaps; irregular sampling retains its real elapsed-time spacing.
- [flutter_animate](https://github.com/gskinner/flutter_animate), pinned to
  4.5.2: card/chart entrances fade once over 180 ms; measurement updates fade
  over 140 ms. There are no repeating effects, blur, or animated terminal output.
  Reduced-motion settings bypass these effects and disable chart transitions.

ForUI 0.26 requires Flutter 3.47 and Dart 3.13. The app's minimum Flutter version
now reflects this; the local toolchain and CI both use Flutter 3.47.1. The root
package retains its existing Dart 3.11 library language version so that existing
Freezed output remains valid; ForUI uses its own Dart 3.13 library language
version. This avoids unrelated regeneration of the app's models.

## Scope and verification

Shared components cover the dashboard, server detail cards, server editor,
settings categories/groups, and terminal connection drawer. Material navigation,
dialogs, SSH sessions, transports, credentials, providers, stores, and actions
retain their existing behavior. No backend changes are needed for this UI work.

Widget regression checks cover form saving and controller ownership, chart gaps
and tooltips, settings persistence/navigation/reordering, lazy list scrolling,
dark mode, landscape, 320-pixel screens, and enlarged text. Animation checks
verify that monitoring refreshes preserve focus and do not replay entrances,
and that reduced motion displays values immediately. Screenshots in
`design-qa/` use fixture data rather than live server measurements.

Real-device iOS frame timing and IPA installation are not verified by these
Windows-hosted widget tests.
