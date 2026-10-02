# v23 settings fixture

`settings.json` was written by `SettingStore` from commit
`c78475a9a537fca20ff27e7352454c6d422427eb`, before the Logo migration.
It contains the persisted (not default-derived) values of the disabled
distribution switch, a custom URL and a custom distribution-name mapping.

Recipe: extract that commit's `lib/data/store/setting.dart` to a temporary
Dart library, open the standard in-memory test database, write the three
values through its properties, and JSON-encode the values read from its store.
Do not regenerate this fixture to accommodate a migration regression.
