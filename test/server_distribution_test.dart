import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/ip_geo.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/globe/painter.dart';
import 'package:server_box/view/widget/globe/view.dart';
import 'package:server_box/view/widget/server_distribution.dart';
import 'package:server_box/view/widget/server_globe.dart';

import 'helpers/geo_fixture.dart';
import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final captureKey = GlobalKey();
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('distribution-');
    Paths.doc = tmp.path;
    Future<void> loadFont(String family, String path) async {
      final file = File(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }

    await loadFont(
      'WarmSans',
      Platform.isWindows
          ? r'C:\Windows\Fonts\msyh.ttc'
          : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    await loadFont(
      'Roboto',
      Platform.isWindows
          ? r'C:\Windows\Fonts\msyh.ttc'
          : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    );
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      await loadFont(
        'MaterialIcons',
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
    }
  });
  tearDownAll(() => tmp.delete(recursive: true));
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('distribution_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
    Stores.setting.serverStatusUpdateInterval.put(0);
    await installGeoVectors();
  });
  tearDown(() async {
    IpGeo.resolver = InternetAddress.lookup;
    await removeGeoVectors();
    await getIt.reset();
    await closeTestDb();
  });

  void add(String id, {String ip = '192.168.1.1', GeoCoord? coord}) {
    Stores.server.put(
      spiFixture(
        id: id,
        name: id,
        ip: ip,
        autoConnect: false,
      ).copyWith(custom: coord == null ? null : ServerCustom(geo: coord)),
    );
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(
    WidgetTester tester,
    List<String> ids, {
    Size size = const Size(393, 852),
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: (dark ? WarmTheme.dark() : WarmTheme.light()).copyWith(
            appBarTheme: (dark ? WarmTheme.dark() : WarmTheme.light())
                .appBarTheme
                .copyWith(
                  titleTextStyle: (dark ? WarmTheme.dark() : WarmTheme.light())
                      .appBarTheme
                      .titleTextStyle
                      ?.copyWith(fontFamily: 'WarmSans'),
                ),
            textTheme: (dark ? WarmTheme.dark() : WarmTheme.light()).textTheme
                .apply(fontFamily: 'WarmSans'),
          ),
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: AppUiScope(child: child!),
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ServerDistributionCard(ids: ids),
                  const SizedBox(height: 1200),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await frames(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  GlobePainter painter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((w) => w.painter)
      .whereType<GlobePainter>()
      .last;
  Future<void> capture(WidgetTester tester, String name) =>
      tester.runAsync(() async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(captureKey))
            .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('design-qa/globe-distribution').create(recursive: true);
        await File(
          'design-qa/globe-distribution/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });

  testWidgets(
    'preview remains static and gives vertical scrolling to homepage',
    (tester) async {
      add('Near', coord: GeoCoord.tryNew(0, 0));
      add('Far', coord: GeoCoord.tryNew(0, 180));
      await show(tester, ['Near', 'Far']);
      final view = tester.widget<GlobeView>(find.byType(GlobeView));
      expect(view.interactive, isFalse);
      expect(view.autoRotate, isFalse);
      final before = painter(tester).projection.camera;
      await tester.pump(const Duration(seconds: 2));
      expect(painter(tester).projection.camera, before);
      await tester.drag(
        find.byKey(const ValueKey('server-distribution-card')),
        const Offset(0, -100),
      );
      await frames(tester);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        greaterThan(0),
      );
      expect(painter(tester).projection.camera, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty filtered list opens and closes without requesting location data',
    (tester) async {
      await show(tester, const []);
      expect(find.text('No servers match the filters'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('server-distribution-card')));
      await frames(tester);
      expect(painter(tester).markers, isEmpty);
      expect(find.text('No servers match the current filters'), findsOneWidget);
      expect(find.text('Download location data'), findsNothing);
      await tester.pageBack();
      await frames(tester);
      expect(find.byType(ServerDistributionPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cluster opens summary, server picker reaches backside, reset and return work',
    (tester) async {
      add('Alpha', coord: GeoCoord.tryNew(0, 0));
      add('Beta', coord: GeoCoord.tryNew(0, 0));
      add('Behind', coord: GeoCoord.tryNew(0, 180));
      await show(tester, ['Alpha', 'Beta', 'Behind']);
      await capture(tester, 'preview');
      await tester.tap(find.byKey(const ValueKey('server-distribution-card')));
      await frames(tester);
      expect(find.byType(ServerDistributionPage), findsOneWidget);
      await tester.tap(find.text('2'));
      await frames(tester);
      expect(find.text('2 servers at this location'), findsOneWidget);
      await tester.tap(find.text('Alpha'));
      await frames(tester);
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Manual coordinates'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      await capture(tester, 'summary');
      await tester.tap(find.byKey(const ValueKey('globe-server-picker')));
      await frames(tester);
      await tester.tap(find.text('Behind'));
      await frames(tester);
      expect(painter(tester).projection.camera.lon.abs(), 180);
      await tester.tap(find.byKey(const ValueKey('globe-reset')));
      await frames(tester);
      expect(painter(tester).projection.camera.lon, 0);
      await tester.tap(find.byType(BackButton));
      await frames(tester);
      expect(find.byType(ServerDistributionPage), findsNothing);
      expect(find.byType(ServerDistributionCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preview and full screen coalesce an in-flight DNS lookup', (
    tester,
  ) async {
    add('DNS', ip: 'geo.example.com');
    var calls = 0;
    final result = Completer<List<InternetAddress>>();
    IpGeo.resolver = (_) {
      calls++;
      return result.future;
    };
    await show(tester, ['DNS']);
    expect(calls, 1);
    await tester.tap(find.byKey(const ValueKey('server-distribution-card')));
    await frames(tester);
    expect(calls, 1);
    result.complete([InternetAddress('8.8.8.8')]);
    await frames(tester);
    expect(calls, 1);
    expect(
      tester.widget<GlobeView>(find.byType(GlobeView).last).items.length,
      1,
    );
    await tester.tap(find.byType(BackButton));
    await frames(tester);
    expect(calls, 1);
  });

  testWidgets(
    'missing data and private servers remain selectable and editable',
    (tester) async {
      await tester.runAsync(removeGeoVectors);
      add('Public', ip: '8.8.8.8');
      add('Private');
      await show(tester, ['Public', 'Private']);
      await tester.tap(find.byKey(const ValueKey('server-distribution-card')));
      await frames(tester);
      expect(find.text('Download location data'), findsOneWidget);
      await tester.tap(find.text('View unplaced servers'));
      await frames(tester);
      await tester.tap(find.text('Private'));
      await frames(tester);
      expect(
        find.text('Private address; set coordinates manually'),
        findsOneWidget,
      );
      expect(find.text('Edit location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small dark and landscape views handle enlarged text and feature switch',
    (tester) async {
      add('Server with a long name', coord: GeoCoord.tryNew(20, 10));
      for (final size in [const Size(320, 740), const Size(740, 320)]) {
        await show(
          tester,
          ['Server with a long name'],
          size: size,
          scale: 1.5,
          dark: true,
        );
        await tester.tap(
          find.byKey(const ValueKey('server-distribution-card')),
        );
        await frames(tester);
        final view = tester.widget<GlobeView>(find.byType(GlobeView).last);
        view.onTapGroup!(['Server with a long name']);
        await frames(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, size.width == 320 ? 'dark-large' : 'landscape');
        Stores.setting.globeEnabled.put(false);
        await frames(tester);
        expect(find.text('Globe is disabled'), findsOneWidget);
        Stores.setting.globeEnabled.put(true);
        await frames(tester);
        expect(find.byType(GlobeView).last, findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await frames(tester);
      }
    },
  );

  testWidgets('server coordinate changes and removal update both views', (
    tester,
  ) async {
    add('Mutable', coord: GeoCoord.tryNew(20, 10));
    await show(tester, ['Mutable']);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerGlobe)),
    );
    await tester.tap(find.byKey(const ValueKey('server-distribution-card')));
    await frames(tester);
    final current = container.read(serversProvider).servers['Mutable']!;
    Stores.server.update(
      current,
      current.copyWith(custom: ServerCustom(geo: GeoCoord.tryNew(-30, 100))),
    );
    await container
        .read(serversProvider.notifier)
        .reload(refreshConnections: false);
    await frames(tester);
    expect(
      tester.widget<GlobeView>(find.byType(GlobeView).last).items.single.coord,
      GeoCoord.tryNew(-30, 100),
    );
    Stores.server.deleteById('Mutable');
    await container
        .read(serversProvider.notifier)
        .reload(refreshConnections: false);
    await frames(tester);
    expect(find.text('No servers match the current filters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
