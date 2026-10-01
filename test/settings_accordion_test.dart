import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();

  setUpAll(() async {
    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await loadFont(
      'SettingsSans',
      Platform.isWindows
          ? r'C:\Windows\Fonts\msyh.ttc'
          : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      await loadFont(
        'MaterialIcons',
        '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
    }
  });

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('accordion_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 848),
    double textScale = 1,
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final theme = dark ? ThemeData.dark() : WarmTheme.light();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ProviderScope(
          child: MaterialApp(
            key: ValueKey('accordion-$size-$textScale-$dark'),
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh'),
            localizationsDelegates: const [
              LibLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme.copyWith(
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'SettingsSans')),
              listTileTheme: theme.listTileTheme.copyWith(
                titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(fontFamily: 'SettingsSans'),
                subtitleTextStyle: theme.listTileTheme.subtitleTextStyle?.copyWith(fontFamily: 'SettingsSans')),
              textTheme: theme.textTheme.apply(fontFamily: 'SettingsSans'),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontFamily: 'SettingsSans',
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: ResponsivePoints.builder(context, child),
            ),
            home: Builder(
              builder: (context) {
                app_locale.l10n = AppLocalizations.of(context)!;
                context.setLibL10n();
                // Home owns this navigation. Reproduce its NavigationBar
                // configuration here to capture the settings in its real
                // available body height, without launching server/FFI setup.
                return Scaffold(
                  body: const SettingsPage(),
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: 2,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        label: '控制台',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.terminal_outlined),
                        label: '终端',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: '设置',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('design-qa')..createSync(recursive: true);
      await File('${dir.path}/$name').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'categories expand inline, close, and expose one group at a time',
    (tester) async {
      await pump(tester);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('终端设置'), findsOneWidget);
      expect(find.text('堡垒机配置'), findsOneWidget);
      await capture(tester, 'settings-accordion-expanded.png');

      await tester.tap(
        find.byKey(const ValueKey('warm-category-toggle-connections')),
      );
      await settle(tester);
      expect(find.text('堡垒机配置'), findsNothing);
      await capture(tester, 'settings-accordion-collapsed.png');

      await tester.tap(
        find.byKey(const ValueKey('warm-category-toggle-appearance')),
      );
      await settle(tester);
      expect(find.text('服务器信息显示'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('warm-category-toggle-connections')),
      );
      await settle(tester);
      expect(find.text('服务器信息显示'), findsNothing);
      expect(find.text('堡垒机配置'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('leaf navigation and both back paths retain the open category', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('堡垒机配置'));
    await settle(tester);
    expect(find.text('请先添加 SSH 服务器，再配置此功能。'), findsOneWidget);
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);
    expect(find.text('隧道配置'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.text('隧道配置'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('堡垒机配置'), findsOneWidget);
    expect(find.text('按分类管理应用偏好'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('server information sheet still reads and writes real switches', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('warm-category-toggle-appearance')),
    );
    await settle(tester);
    await tester.tap(find.text('服务器信息显示'));
    await settle(tester);
    expect(find.byType(SwitchListTile), findsNWidgets(4));
    expect(find.byKey(const ValueKey('server-info-back')), findsNothing);
    Stores.setting.probeNetflix.put(true);
    await tester.tap(find.widgetWithText(SwitchListTile, 'ChatGPT'));
    await settle(tester);
    expect(Stores.setting.probeChatGpt.fetch(), isTrue);
    await tester.tap(find.byType(BackButton).first);
    await settle(tester);
    expect(find.text('服务器信息显示'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dashboard information sheet has its own back button and preserves switches',
    (tester) async {
      await pump(tester);
      Stores.setting.probeNetflix.put(true);
      unawaited(SettingsPage.showServerInfo(tester.element(find.byType(SettingsPage))));
      await settle(tester);
      final back = find.byKey(const ValueKey('server-info-back'));
      expect(back.hitTestable(), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNWidgets(4));
      await capture(tester, 'server-info-back-button.png');
      await tester.tap(back);
      await settle(tester);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(Stores.setting.probeNetflix.fetch(), isTrue);
      expect(find.text('按分类管理应用偏好'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small screen, landscape, large text and dark mode remain usable',
    (tester) async {
      for (final config in [
        (const Size(320, 568), 1.0, false),
        (const Size(568, 320), 1.0, false),
        (const Size(390, 848), 2.0, false),
        (const Size(390, 848), 1.0, true),
      ]) {
        await pump(
          tester,
          size: config.$1,
          textScale: config.$2,
          dark: config.$3,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('warm-category-toggle-application')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(
          find.byKey(const ValueKey('warm-category-toggle-application')),
        );
        await settle(tester);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('warm-setting-about.openSource')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find
              .byKey(const ValueKey('warm-setting-about.openSource'))
              .hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (config.$2 == 2) {
          await capture(tester, 'settings-accordion-large-text.png');
        }
        if (config.$3) {
          await capture(tester, 'settings-accordion-dark.png');
        }
      }
    },
  );
}
