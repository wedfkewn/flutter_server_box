import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  late SettingStore setting;

  setUp(() {
    SqliteDb.openInMemory();
    setting = SettingStore('default_locale_test');
  });

  tearDown(() => SqliteDb.close());

  test('a fresh install defaults to Chinese', () {
    expect(setting.needsInitialChineseLocale, isTrue);
  });

  test('an upgrade without an explicit locale preserves system language', () {
    setting.lastVer.put(1578);
    expect(setting.locale.fetch(), isEmpty);
    expect(setting.needsInitialChineseLocale, isFalse);
  });

  test('an existing locale is never replaced', () {
    setting.locale.put('en');
    expect(setting.needsInitialChineseLocale, isFalse);
  });
}
