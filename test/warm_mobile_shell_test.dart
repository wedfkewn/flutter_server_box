import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/benchmark/log_view.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/page/setting/entry.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  final captureKey = GlobalKey();

  setUpAll(() async {
    Future<void> loadFont(String family, String path) async {
      final font = File(path);
      if (!font.existsSync()) return;
      final bytes = await font.readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await loadFont(
      'WarmSans',
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      await loadFont(
        'MaterialIcons',
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
            'MaterialIcons-Regular.otf',
      );
    }
  });

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('warm-mobile-shell-');
    Paths.doc = temp.path;
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(
      spiFixture(
        id: 'std20',
        name: 'STD20',
        ip: 'raksmart.com',
        user: 'root',
        autoConnect: false,
        tags: ['US', 'Ubuntu 24.04 LTS', 'x86_64'],
      ),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
    await temp.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    Widget child = const ServerPage(),
  }) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final warmTheme = WarmTheme.light();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: warmTheme.copyWith(
              textTheme: warmTheme.textTheme.apply(fontFamily: 'WarmSans'),
              primaryTextTheme: warmTheme.primaryTextTheme.apply(
                fontFamily: 'WarmSans',
              ),
              chipTheme: warmTheme.chipTheme.copyWith(
                labelStyle: warmTheme.textTheme.labelLarge?.copyWith(
                  fontFamily: 'WarmSans',
                ),
                secondaryLabelStyle: warmTheme.textTheme.labelLarge?.copyWith(
                  fontFamily: 'WarmSans',
                ),
              ),
            ),
            localizationsDelegates: const [
              LibLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            builder: ResponsivePoints.builder,
            home: child,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    });
  }

  testWidgets('renders the warm dashboard and opens alert settings', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('总览'), findsOneWidget);
    expect(find.text('我的服务器'), findsOneWidget);
    expect(find.text('STD20'), findsOneWidget);
    expect(find.text('告警'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byIcon(Icons.public), findsNothing);
    expect(find.byIcon(Icons.travel_explore), findsOneWidget);
    await capture(tester, 'implementation-dashboard.png');

    await tester.tap(find.text('告警'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('告警设置'), findsOneWidget);
    expect(find.text('CPU 使用率告警'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    await capture(tester, 'implementation-alert.png');

    await tester.tap(find.text('取消'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pump(tester, child: const SettingsPage());

    expect(find.text('外观与显示'), findsOneWidget);
    expect(find.text('安全与数据'), findsOneWidget);
    await capture(tester, 'implementation-settings.png');

    await tester.tap(find.text('外观与显示'));
    await tester.pumpAndSettle();
    expect(find.text('服务器信息显示'), findsOneWidget);
    await tester.tap(find.text('服务器信息显示'));
    await tester.pumpAndSettle();
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Gemini'), findsOneWidget);

    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    for (final category in [
      '外观与显示',
      '服务器与监控',
      '连接与终端',
      '文件与容器',
      '安全与数据',
      '应用与关于',
    ]) {
      expect(find.text(category), findsOneWidget);
    }
    await tester.tap(find.text('应用与关于'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开源项目说明'));
    await tester.pumpAndSettle();
    expect(find.text('原项目仓库'), findsOneWidget);
    expect(find.text('第三方依赖许可证'), findsOneWidget);
    expect(find.text('GNU AGPLv3 完整许可证'), findsOneWidget);
    await tester.tap(find.text('GNU AGPLv3 完整许可证'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('GNU AFFERO GENERAL PUBLIC LICENSE'),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(find.text('开源项目说明'), findsOneWidget);

    await pump(
      tester,
      child: const Scaffold(
        body: BenchmarkLogView(
          height: 852,
          log:
              '\x1b[36m/* tiny hex dumper */\x1b[0m\n'
              '#include <stdio.h>\n\n'
              '\x1b[34m#define\x1b[0m N 16\n\n'
              '\x1b[32mint\x1b[0m main(int argc, char **argv) {\n'
              '  FILE *f = argc > 1 ? fopen(argv[1], "rb") : stdin;\n'
              '  unsigned char buf[N];\n'
              '  unsigned long off = 0;\n\n'
              '  while ((n = fread(buf, 1, N, f)) > 0) {\n'
              '    printf("%08lX  ", off);\n'
              '    off += n;\n'
              '  }\n'
              '  return 0;\n'
              '}\n',
        ),
      ),
    );
    await capture(tester, 'implementation-terminal.png');
  });
}
