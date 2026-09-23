import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';

import 'helpers/test_db.dart';

/// The same six categories appear as a rail on desktop and a two-level list
/// on mobile. The old floating-tabs assertions no longer describe this UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-settings-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: const SettingsPage(),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  final categories = [
    'Appearance & display',
    'Servers & monitoring',
    'Connections & terminal',
    'Files & containers',
    'Security & data',
    'App & about',
  ];

  testWidgets('desktop rail contains the six categories and real leaves', (
    tester,
  ) async {
    await pump(tester, width: 1200);
    final rail = find.byKey(settingsMenuKey);
    expect(rail, findsOneWidget);
    for (final title in categories) {
      expect(
        find.descendant(of: rail, matching: find.text(title)),
        findsOneWidget,
      );
    }
    expect(find.byKey(settingsTabsKey), findsNothing);
    await tester.tap(
      find.descendant(of: rail, matching: find.text('Connections & terminal')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: rail, matching: find.text('Bastion configuration')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rail, matching: find.text('Tunnel configuration')),
      findsNothing,
    );
  });

  testWidgets('mobile category, leaf, and back navigation stay two-level', (
    tester,
  ) async {
    await pump(tester, width: 500);
    for (final title in categories) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byKey(settingsTabsKey), findsNothing);
    await tester.tap(find.text('Appearance & display'));
    await tester.pumpAndSettle();
    expect(find.text('Server information display'), findsOneWidget);
    await tester.tap(find.text('Server information display'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsNWidgets(4));
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('Server information display'), findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    for (final title in categories) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('bastion entry selects an SSH server', (tester) async {
    await pump(tester, width: 500);
    await tester.tap(find.text('Connections & terminal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bastion configuration'));
    await tester.pumpAndSettle();
    expect(
      find.text('Add an SSH server to configure this feature.'),
      findsOneWidget,
    );
  });

  testWidgets('open-source detail displays source and license entries', (
    tester,
  ) async {
    await pump(tester, width: 500);
    await tester.tap(find.text('App & about'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open-source project'));
    await tester.pumpAndSettle();
    expect(find.text('Original project repository'), findsOneWidget);
    expect(find.text('Third-party dependency licenses'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full GNU AGPLv3 license'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('GNU AFFERO GENERAL PUBLIC LICENSE'),
      findsOneWidget,
    );
  });
}
