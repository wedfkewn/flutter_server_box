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
import 'package:forui/localizations.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/model/app/ip_lookup.dart';
import 'package:server_box/data/model/app/service_reachability.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/external_probe.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/ip_lookup_cache.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/service_reachability_cache.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/tab/tab.dart';
import 'package:server_box/view/widget/app_ui.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

const _serverId = 'dashboard-data-fixture';
const _publicIp = '43.138.167.180';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();
  late Directory temp;
  late Spi spi;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('warm-dashboard-data-');
    Paths.doc = temp.path;
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
      Platform.isWindows
          ? r'C:\Windows\Fonts\msyh.ttc'
          : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
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
    await openTestDb();
    getIt.registerSingleton<SettingStore>(
      SettingStore('dashboard_setting_test'),
    );
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(
      SelfAddrStore('dashboard_addr_test'),
    );
    getIt.registerSingleton<IpLookupCacheStore>(
      IpLookupCacheStore('dashboard_ip_test'),
    );
    getIt.registerSingleton<ServiceReachabilityCacheStore>(
      ServiceReachabilityCacheStore('dashboard_service_test'),
    );
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.setting.globeEnabled.put(false);
    Stores.setting.fullScreenJitter.put(false);
    spi = spiFixture(
      id: _serverId,
      name: '123',
      ip: _publicIp,
      user: 'ubuntu',
      autoConnect: false,
    );
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });
  tearDownAll(() => temp.delete(recursive: true));

  Future<void> pumpDashboard(
    WidgetTester tester,
    _DashboardServer notifier, {
    Size size = const Size(393, 852),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final warm = WarmTheme.light();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: ProviderScope(
          key: UniqueKey(),
          overrides: [serverProvider(_serverId).overrideWith(() => notifier)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: warm.copyWith(
              textTheme: warm.textTheme.apply(fontFamily: 'WarmSans'),
              primaryTextTheme: warm.primaryTextTheme.apply(
                fontFamily: 'WarmSans',
              ),
              chipTheme: warm.chipTheme.copyWith(
                labelStyle: warm.textTheme.labelLarge?.copyWith(
                  fontFamily: 'WarmSans',
                ),
                secondaryLabelStyle: warm.textTheme.labelLarge?.copyWith(
                  fontFamily: 'WarmSans',
                ),
              ),
            ),
            localizationsDelegates: const [
              FLocalizations.delegate, LibLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AppUiScope(child: ResponsivePoints.builder(
              context,
              MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
            )),
            home: const ServerPage(),
          ),
        ),
      ),
    );
    await settleFrames(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> capture(
    WidgetTester tester, {
    String fileName = 'implementation-dashboard-data.png',
  }) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('design-qa')..createSync(recursive: true);
      await File(
        '${dir.path}/$fileName',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void enableChecks({bool gemini = false}) {
    Stores.setting.probeChatGpt.put(true);
    Stores.setting.probeNetflix.put(true);
    Stores.setting.probeGemini.put(gemini);
  }

  void seedState(ServiceKind service, ServiceReachabilityState state) {
    expect(
      Stores.serviceReachabilityCache.put(
        spi.id,
        spi.displayAddr,
        reading(service, state),
      ),
      isTrue,
    );
  }

  testWidgets(
    'server observations and cached network metadata render on the homepage',
    (tester) async {
      // Screenshot-derived sample values are a test fixture, never app defaults.
      Stores.setting.ipLookupConsent.put(true);
      Stores.setting.showServerNetworkInfo.put(true);
      expect(
        Stores.ipLookupCache.putResult(
          spi.id,
          IpLookupResult(
            ip: _publicIp,
            type: 'IPv4',
            country: '中国',
            countryCode: 'CN',
            flagEmoji: '🇨🇳',
            organization: 'Tencent Cloud Computing (Beijing) Co., Ltd.',
            networkDomain: 'tencentcloud.com',
            asn: 45090,
            isp: 'Shenzhen Tencent Computer Systems Company Limited',
            fetchedAt: DateTime.now(),
          ),
        ),
        isTrue,
      );
      final notifier = _DashboardServer(
        ServerState(
          spi: spi,
          status: observedStatus(),
          conn: ServerConn.finished,
        ),
      );
      await pumpDashboard(tester, notifier);

      for (final label in [
        '服务器信息',
        '外网服务',
        'ubuntu',
        'ubuntu@43.138.167.180:22',
        '🇨🇳 CN',
        'Tencent Cloud Computing (Beijing) Co., Ltd.',
        'tencentcloud.com',
        'AS45090',
        'Shenzhen Tencent Computer Systems Company Limited',
        'AMD EPYC 7K62 48-Core Processor',
        '1%',
        '36%',
        '45%',
        '5 核',
        '1.3/3.6 GB',
        '18/39 GB',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('ChatGPT · 未检测'), findsOneWidget);
      expect(find.text('Google · 未检测'), findsOneWidget);
      expect(notifier.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await capture(tester);

      // Capture the same live card with enabled, cached checks. Enabling the
      // controls must update an existing card without a network request.
      seedState(ServiceKind.chatGpt, ServiceReachabilityState.reachable);
      seedState(ServiceKind.netflix, ServiceReachabilityState.unreachable);
      enableChecks();
      await settleFrames(tester);
      expect(find.text('ChatGPT · 网站响应'), findsOneWidget);
      expect(find.text('Netflix · 响应异常'), findsOneWidget);
      expect(notifier.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await capture(tester, fileName: 'implementation-dashboard-checks.png');
    },
  );

  testWidgets(
    'missing measurements remain absent instead of becoming zero readings',
    (tester) async {
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus()),
      );
      await pumpDashboard(tester, notifier);

      expect(find.text('—'), findsAtLeastNWidgets(8));
      expect(find.text('0%'), findsNothing);
      expect(find.text('0.0/0.0 GB'), findsNothing);
      expect(find.text('0 B/s'), findsNothing);
      expect(find.text('0 核'), findsNothing);
      expect(notifier.requests, isEmpty);
      expect(notifier.execCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial status placeholders are not measured memory or disk readings',
    (tester) async {
      await pumpDashboard(
        tester,
        _DashboardServer(ServerState(spi: spi, status: InitStatus.status)),
      );
      expect(find.text('—'), findsAtLeastNWidgets(8));
      expect(find.text('0%'), findsNothing);
      expect(find.text('0.0/0.0 GB'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cached reachable, unreachable and unknown checks display independently',
    (tester) async {
      enableChecks(gemini: true);
      seedState(ServiceKind.chatGpt, ServiceReachabilityState.reachable);
      seedState(ServiceKind.netflix, ServiceReachabilityState.unreachable);
      seedState(ServiceKind.gemini, ServiceReachabilityState.unknown);
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, notifier);

      expect(find.text('ChatGPT · 网站响应'), findsOneWidget);
      expect(find.text('Netflix · 响应异常'), findsOneWidget);
      expect(find.text('Gemini · 待确认'), findsOneWidget);
      expect(notifier.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'default selections stay manual and make no requests on an online server',
    (tester) async {
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, notifier);

      expect(find.text('ChatGPT · 未检测'), findsOneWidget);
      expect(find.text('Google · 未检测'), findsOneWidget);
      expect(notifier.requests, isEmpty);
      expect(notifier.execCalls, 0);
      expect(notifier.refreshCalls, 0);
    },
  );

  testWidgets(
    'uncached checks wait while a server is disconnected or still connecting',
    (tester) async {
      enableChecks();
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus()),
      );
      await pumpDashboard(tester, notifier);

      expect(find.text('ChatGPT · 未检测'), findsOneWidget);
      expect(find.text('Netflix · 未检测'), findsOneWidget);
      expect(notifier.requests, isEmpty);
      notifier.replace(notifier.snapshot.copyWith(conn: ServerConn.connected));
      await settleFrames(tester);
      expect(notifier.requests, isEmpty);
      expect(find.text('ChatGPT · 未检测'), findsOneWidget);
      expect(notifier.execCalls, 0);
      expect(notifier.refreshCalls, 0);
    },
  );

  testWidgets(
    'checks start after monitoring finishes and persist each returned result',
    (tester) async {
      enableChecks();
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus()),
      );
      await pumpDashboard(tester, notifier);
      notifier.replace(notifier.snapshot.copyWith(conn: ServerConn.finished));
      await settleFrames(tester);

      expect(notifier.requests, [
        {ServiceKind.chatGpt, ServiceKind.netflix},
      ]);
      expect(find.text('ChatGPT · 检测中'), findsOneWidget);
      expect(find.text('Netflix · 检测中'), findsOneWidget);
      notifier.finish(0, {
        ServiceKind.chatGpt: reading(
          ServiceKind.chatGpt,
          ServiceReachabilityState.reachable,
        ),
        ServiceKind.netflix: reading(
          ServiceKind.netflix,
          ServiceReachabilityState.unreachable,
        ),
      });
      await settleFrames(tester);

      expect(find.text('ChatGPT · 网站响应'), findsOneWidget);
      expect(find.text('Netflix · 响应异常'), findsOneWidget);
      expect(Stores.serviceReachabilityCache.external(spi.id,
        externalProbeScope(notifier.snapshot), ProbeCatalog.targets.firstWhere((e) => e.id == 'netflix'))?.state,
        ProbeState.rejected);
      notifier.replace(notifier.snapshot.copyWith(conn: ServerConn.loading));
      await settleFrames(tester);
      notifier.replace(notifier.snapshot.copyWith(conn: ServerConn.finished));
      await settleFrames(tester);
      expect(notifier.requests.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an omitted result and a probe error show unavailable without false successes',
    (tester) async {
      enableChecks();
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, notifier);
      notifier.finish(0, {
        ServiceKind.chatGpt: reading(
          ServiceKind.chatGpt,
          ServiceReachabilityState.reachable,
        ),
      });
      await settleFrames(tester);
      expect(find.text('ChatGPT · 网站响应'), findsOneWidget);
      expect(find.text('Netflix · 待确认'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      Stores.serviceReachabilityCache.clear();
      final failing = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, failing);
      failing.fail(0);
      await settleFrames(tester);
      expect(find.text('ChatGPT · 待确认'), findsOneWidget);
      expect(find.text('Netflix · 待确认'), findsOneWidget);
      expect(find.text('ChatGPT · 网站响应'), findsNothing);
      expect(
        Stores.serviceReachabilityCache.fresh(
          spi.id,
          spi.displayAddr,
          ServiceKind.chatGpt,
        ),
        isNull,
        reason: 'new observations do not write the legacy cache',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching the endpoint discards the old in-flight response and cache',
    (tester) async {
      enableChecks();
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, notifier);
      final nextSpi = spiFixture(
        id: spi.id,
        name: spi.name,
        ip: '43.138.167.181',
        user: 'ubuntu',
        autoConnect: false,
      );
      notifier.replace(notifier.snapshot.copyWith(spi: nextSpi));
      await settleFrames(tester);
      expect(notifier.requests.length, 1, reason: 'Wait for the bounded old batch to finish');

      notifier.finish(0, {
        ServiceKind.chatGpt: reading(
          ServiceKind.chatGpt,
          ServiceReachabilityState.reachable,
        ),
        ServiceKind.netflix: reading(
          ServiceKind.netflix,
          ServiceReachabilityState.reachable,
        ),
      });
      await settleFrames(tester);
      expect(find.text('ChatGPT · 检测中'), findsOneWidget);
      expect(find.text('Netflix · 检测中'), findsOneWidget);
      expect(
        Stores.serviceReachabilityCache.fresh(
          spi.id,
          spi.displayAddr,
          ServiceKind.chatGpt,
        ),
        isNull,
      );
      notifier.finish(1, {
        ServiceKind.chatGpt: reading(
          ServiceKind.chatGpt,
          ServiceReachabilityState.unreachable,
        ),
        ServiceKind.netflix: reading(
          ServiceKind.netflix,
          ServiceReachabilityState.unknown,
        ),
      });
      await settleFrames(tester);
      expect(find.text('ChatGPT · 响应异常'), findsOneWidget);
      expect(find.text('Netflix · 待确认'), findsOneWidget);
      expect(Stores.serviceReachabilityCache.external(spi.id,
        externalProbeScope(notifier.snapshot), ProbeCatalog.targets.firstWhere((e) => e.id == 'chatGpt'))?.state,
        ProbeState.rejected);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an unmounted card ignores a late response without publishing a cache entry',
    (tester) async {
      enableChecks();
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, notifier);
      expect(notifier.requests.length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      notifier.finish(0, {
        ServiceKind.chatGpt: reading(
          ServiceKind.chatGpt,
          ServiceReachabilityState.reachable,
        ),
      });
      await settleFrames(tester);

      expect(
        Stores.serviceReachabilityCache.fresh(
          spi.id,
          spi.displayAddr,
          ServiceKind.chatGpt,
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'turning checks off discards pending responses and keeps them out of the cache',
    (tester) async {
      enableChecks();
      final notifier = _DashboardServer(
        ServerState(spi: spi, status: emptyStatus(), conn: ServerConn.finished),
      );
      await pumpDashboard(tester, notifier);
      expect(notifier.requests.length, 1);
      Stores.setting.probeChatGpt.put(false);
      Stores.setting.probeNetflix.put(false);
      await settleFrames(tester);
      notifier.finish(0, {
        ServiceKind.chatGpt: reading(
          ServiceKind.chatGpt,
          ServiceReachabilityState.reachable,
        ),
        ServiceKind.netflix: reading(
          ServiceKind.netflix,
          ServiceReachabilityState.reachable,
        ),
      });
      await settleFrames(tester);

      expect(find.text('ChatGPT · 未检测'), findsOneWidget);
      expect(find.text('Google · 未检测'), findsOneWidget);
      for (final service in [ServiceKind.chatGpt, ServiceKind.netflix]) {
        expect(
          Stores.serviceReachabilityCache.fresh(
            spi.id,
            spi.displayAddr,
            service,
          ),
          isNull,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'data and all check states fit 393 and 320 pixel phones including enlarged text',
    (tester) async {
      enableChecks(gemini: true);
      seedState(ServiceKind.chatGpt, ServiceReachabilityState.reachable);
      seedState(ServiceKind.netflix, ServiceReachabilityState.unreachable);
      seedState(ServiceKind.gemini, ServiceReachabilityState.unknown);
      for (final size in [const Size(393, 852), const Size(320, 740)]) {
        for (final scale in [1.0, 1.3]) {
          await pumpDashboard(
            tester,
            _DashboardServer(
              ServerState(
                spi: spi,
                status: observedStatus(),
                conn: ServerConn.finished,
              ),
            ),
            size: size,
            textScale: scale,
          );
          expect(find.text('服务器信息'), findsOneWidget);
          expect(find.text('外网服务'), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$size, scale $scale');
        }
      }
    },
  );
}

Future<void> settleFrames(WidgetTester tester) async {
  // Monitoring pages own periodic timers; pump a finite number of frames.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

ServiceReachabilityResult reading(
  ServiceKind service,
  ServiceReachabilityState state,
) => ServiceReachabilityResult(
  service: service,
  state: state,
  checkedAt: DateTime.now(),
);

ServerStatus emptyStatus() => InitStatus.status
  ..mem = const Memory(total: 0, free: 0, avail: 0)
  ..disk = []
  ..diskUsage = null;

ServerStatus observedStatus() {
  final status = emptyStatus();
  status.osId = 'ubuntu';
  status.ips = [_publicIp];
  status.cpu.brand['AMD EPYC 7K62 48-Core Processor'] = 5;
  status.cpu.update([
    for (var i = 0; i < 5; i++) SingleCpuCore('cpu$i', 10, 0, 0, 1000, 0, 0, 0),
  ]);
  status.cpu.update([
    for (var i = 0; i < 5; i++) SingleCpuCore('cpu$i', 11, 0, 0, 1099, 0, 0, 0),
  ]);
  final totalMemory = (3.6 * 1024 * 1024).round();
  status.mem = Memory(
    total: totalMemory,
    free: 0,
    avail: (totalMemory * .64).round(),
  );
  status.diskUsage = DiskUsage(
    size: BigInt.from(39 * 1024 * 1024),
    used: BigInt.from((39 * .45 * 1024 * 1024).round()),
  );
  return status;
}

/// This fixture cannot open SSH or call an external detection/IP endpoint.
/// Tests decide when each asynchronous response lands on the real widget.
class _DashboardServer extends ServerNotifier {
  _DashboardServer(this.snapshot);

  ServerState snapshot;
  final requests = <Set<ServiceKind>>[];
  final _pending = <Completer<Map<ServiceKind, ServiceReachabilityResult>>>[];
  int execCalls = 0;
  int refreshCalls = 0;

  @override
  ServerState build(String serverId) => snapshot;

  void replace(ServerState next) {
    snapshot = next;
    state = next;
  }

  @override
  Future<Map<ServiceKind, ServiceReachabilityResult>> probeServices(
    Set<ServiceKind> services,
  ) {
    requests.add(Set.of(services));
    final pending = Completer<Map<ServiceKind, ServiceReachabilityResult>>();
    _pending.add(pending);
    return pending.future;
  }

  @override
  Future<Map<String, ProbeResult>> probeExternalServices(List<ProbeTarget> targets) {
    final services = targets.map((e) => ServiceKind.values.byName(e.id)).toSet();
    return probeServices(services).then((results) => {for (final entry in results.entries)
      entry.key.name: ProbeResult(id: entry.key.name,
        state: switch (entry.value.state) {
          ServiceReachabilityState.reachable => ProbeState.reachable,
          ServiceReachabilityState.unreachable => ProbeState.rejected,
          ServiceReachabilityState.unknown => ProbeState.unknown,
        }, reason: entry.value.reachable ? 'httpResponse' : 'network',
        checkedAt: entry.value.checkedAt, transport: 'Fixture')});
  }

  void finish(int index, Map<ServiceKind, ServiceReachabilityResult> results) =>
      _pending[index].complete(results);

  void fail(int index) =>
      _pending[index].completeError(StateError('Fixture probe failed'));

  @override
  Future<ServerExec> ensureExec() async {
    execCalls++;
    throw StateError('Dashboard fixture must never open a connection');
  }

  @override
  Future<void> refresh({bool interactive = false}) async {
    refreshCalls++;
  }
}
