import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/app_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingStore setting;
  setUp(() {
    SqliteDb.openInMemory();
    setting = SettingStore('theme_test');
    getIt.registerSingleton<SettingStore>(setting);
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() async { await getIt.reset(); await SqliteDb.close(); });

  testWidgets('saved seed updates the actual app and ForUI without RNodes notification', (tester) async {
    setting.colorSeed.put(0xffd32f2f);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final before = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final navigator = tester.state(find.byType(Navigator).first);
    expect(before.theme!.colorScheme.primary, WarmTheme.light(seedColor: const Color(0xffd32f2f)).colorScheme.primary);
    setting.colorSeed.put(0xff278438);
    await tester.pumpAndSettle();
    final after = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(after.theme!.colorScheme.primary, isNot(before.theme!.colorScheme.primary));
    expect(tester.state(find.byType(Navigator).first), same(navigator));
    expect(after.themeAnimationDuration, Duration.zero);
    final context = tester.element(find.byType(AppUiScope));
    expect(FTheme.of(tester.element(find.byType(ToastHost))).colors.primary,
      Theme.of(context).colorScheme.primary);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('system color fallback and theme changes keep the same navigator', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final navigator = tester.state(find.byType(Navigator).first);
    setting.useSystemPrimaryColor.put(true);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(Navigator).first), same(navigator));
    setting.themeMode.put(2);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppUiScope))).brightness, Brightness.dark);
    setting.themeMode.put(3);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppUiScope))).scaffoldBackgroundColor, Colors.black);
    setting.themeMode.put(0);
    await tester.pumpAndSettle();
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppUiScope))).brightness, Brightness.dark);
    setting.themeMode.put(4);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppUiScope))).scaffoldBackgroundColor, Colors.black);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(AppUiScope))).brightness, Brightness.light);
    expect(tester.state(find.byType(Navigator).first), same(navigator));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
