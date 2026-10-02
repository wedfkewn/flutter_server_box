import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/localizations.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/frb_generated.dart';
import 'package:server_box/view/page/port_forward.dart';
import 'package:server_box/view/page/process.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/services.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';
import 'warm_dashboard_data_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();
  final spi = spiFixture(id: 'five-pages', name: '123', ip: '43.138.167.180',
    user: 'ubuntu', pwd: 'fixture-password', autoConnect: false);

  test('dark page and grouped text retain readable contrast', () {
    final theme = WarmTheme.dark();
    double contrast(Color foreground, Color background) {
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
    }
    for (final surface in [theme.scaffoldBackgroundColor, theme.colorScheme.surfaceContainerLow]) {
      expect(contrast(theme.textTheme.bodyMedium!.color!, surface), greaterThanOrEqualTo(4.5));
      expect(contrast(theme.textTheme.bodySmall!.color!, surface), greaterThanOrEqualTo(4.5));
      expect(contrast(theme.listTileTheme.titleTextStyle!.color!, surface), greaterThanOrEqualTo(4.5));
    }
  });
  late ProviderContainer container;
  late _PageServer server;

  setUpAll(() async {
    if (Platform.isWindows && File('build/native_assets/windows/sbm_ffi.dll').existsSync()) {
      await RustLib.init(externalLibrary: ExternalLibrary.open('build/native_assets/windows/sbm_ffi.dll'));
    } else {
      await initRustLibForTest();
    }
    Paths.doc = Directory('.tools/server-pages-capture').absolute.path;
    Directory(Paths.doc).createSync(recursive: true);
    Future<void> font(String name, String path) async {
      if (!File(path).existsSync()) return;
      final data = await File(path).readAsBytes();
      await (FontLoader(name)..addFont(Future.value(ByteData.sublistView(data)))).load();
    }
    await font('ServerSans', Platform.isWindows ? r'C:\Windows\Fonts\msyh.ttc' : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    final icons = Directory('.tools/pub-cache/git').listSync().whereType<Directory>()
      .where((dir) => dir.path.contains('icons_plus-')).first;
    for (final family in ['MingCute','BoxIcons','Bootstrap','FontAwesome']) {
      await font('packages/icons_plus/$family', '${icons.path}/assets/fonts/$family.ttf');
    }
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) await font('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('server_pages_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('server_pages_addr'));
    getIt.registerSingleton<PortForwardStore>(PortForwardStore());
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.setting.portForwardBetaWarned.put(true);
    Stores.setting.collapseUIDefault.put(false);
    Stores.server.put(spi);
    final status = fixture.observedStatus();
    status.more[StatusCmdType.sys] = 'Ubuntu 24.04.4 LTS';
    status.more[StatusCmdType.host] = 'VM-0-11-ubuntu';
    status.more[StatusCmdType.uptime] = '2 days, 7:31';
    for (var i = 0; i < 25; i++) {
      status.history.add(timeMs: DateTime(2026, 10, 1, 16).millisecondsSinceEpoch + i * 3000,
        cpu: 1 + (i % 5) * .15, mem: 36 + (i % 3) * .2, disk: 45);
    }
    server = _PageServer(ServerState(spi: spi, status: status, conn: ServerConn.finished));
    container = ProviderContainer(overrides: [
      serversProvider.overrideWith(() => _PageServers(spi)),
      serverProvider(spi.id).overrideWith(() => server),
      servicesProvider(spi).overrideWith(() => _PageServices()),
      privateKeyProvider.overrideWithValue(const PrivateKeyState()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) { await tester.pump(const Duration(milliseconds: 50)); }
  }

  Widget page(String name) => switch (name) {
    'editor' => ServerEditPage(args: SpiRequiredArgs(spi)),
    'detail' => ServerDetailPage(args: SpiRequiredArgs(spi)),
    'process' => ProcessPage(args: SpiRequiredArgs(spi)),
    'services' => ServicesPage(args: SpiRequiredArgs(spi)),
    _ => PortForwardPage(args: SpiRequiredArgs(spi)),
  };

  Future<void> pump(WidgetTester tester, String name, {
    Size size = const Size(390, 844), double scale = 1, bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final warm = WarmTheme.mobilePolish(dark ? WarmTheme.dark() : WarmTheme.light());
    final theme = warm.copyWith(
      filledButtonTheme: FilledButtonThemeData(style: warm.filledButtonTheme.style?.copyWith(
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'ServerSans', fontWeight: FontWeight.w700)))),
      appBarTheme: warm.appBarTheme.copyWith(titleTextStyle: warm.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'ServerSans')),
      chipTheme: warm.chipTheme.copyWith(labelStyle: warm.chipTheme.labelStyle?.copyWith(fontFamily: 'ServerSans'),
        secondaryLabelStyle: warm.chipTheme.secondaryLabelStyle?.copyWith(fontFamily: 'ServerSans')),
      textTheme: warm.textTheme.apply(fontFamily: 'ServerSans'),
      primaryTextTheme: warm.primaryTextTheme.apply(fontFamily: 'ServerSans'),
      listTileTheme: warm.listTileTheme.copyWith(
        titleTextStyle: warm.listTileTheme.titleTextStyle?.copyWith(fontFamily: 'ServerSans'),
        subtitleTextStyle: warm.listTileTheme.subtitleTextStyle?.copyWith(fontFamily: 'ServerSans')),
    );
    await tester.pumpWidget(RepaintBoundary(key: captureKey,
      child: UncontrolledProviderScope(container: container, child: MaterialApp(
        key: UniqueKey(), debugShowCheckedModeBanner: false, theme: theme,
        localizationsDelegates: const [FLocalizations.delegate, LibLocalizations.delegate, ...AppLocalizations.localizationsDelegates],
        locale: const Locale('zh'), supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppUiScope(child: ResponsivePoints.builder(context, MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!))),
        initialRoute: '/page',
        routes: {'/': (_) => const SizedBox.shrink(), '/page': (context) => Builder(builder: (context) {
          app_locale.l10n = AppLocalizations.of(context)!;
          context.setLibL10n();
          return Scaffold(body: page(name), bottomNavigationBar: NavigationBar(
            selectedIndex: 0, onDestinationSelected: (_) {},
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '控制台'),
              NavigationDestination(icon: Icon(Icons.terminal), label: '终端'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
            ],
          ));
        })},
      )),
    ));
    await frames(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('design-qa').createSync(recursive: true);
      await File('design-qa/server-pages-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final name in ['editor', 'detail', 'process', 'services', 'forward']) {
    testWidgets('$name mobile render and capture', (tester) async {
      await pump(tester, name);
      expect(tester.takeException(), isNull);
      await capture(tester, name);
      await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
    });
    testWidgets('$name small screen enlarged text and dark mode', (tester) async {
      await pump(tester, name, size: const Size(320, 740), scale: 1.5);
      expect(tester.takeException(), isNull);
      await capture(tester, '$name-large');
      await pump(tester, name, dark: true);
      expect(tester.takeException(), isNull);
      await capture(tester, '$name-dark');
      await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
    });
  }

  testWidgets('editor supports dual transport without losing typed host', (tester) async {
    await pump(tester, 'editor');
    final host = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '43.138.167.180');
    await tester.enterText(host, '192.0.2.42');
    final monitorSwitch = find.descendant(of: find.widgetWithText(SwitchListTile, 'Monitor HTTP'), matching: find.byType(Switch));
    await tester.ensureVisible(monitorSwitch);
    await tester.tap(monitorSwitch);
    await frames(tester);
    expect(find.text(app_locale.l10n.preferredTransport), findsOneWidget);
    expect(find.text('192.0.2.42'), findsOneWidget);
    final ssh = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'SSH'));
    expect(ssh.value, isTrue);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('server editor selection menu stays compact with the keyboard open', (tester) async {
    await pump(tester, 'editor');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await frames(tester);
    final name = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '123');
    await tester.ensureVisible(name);
    await tester.tap(name);
    await frames(tester);
    final state = tester.state<EditableTextState>(name);
    state.widget.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();
    state.showToolbar();
    await frames(tester);
    final toolbar = find.byType(TextSelectionToolbar);
    expect(toolbar, findsOneWidget);
    final surface = find.descendant(of: toolbar, matching: find.byType(Material)).first;
    expect(tester.getSize(surface).height, lessThan(100));
    expect(state.widget.controller.text, '123');
    expect(tester.takeException(), isNull);
    await capture(tester, 'editor-keyboard-menu');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('detail exposes all permitted configured tools without a floating strip', (tester) async {
    await pump(tester, 'detail');
    expect(tester.widget<ServerFuncBtns>(find.byType(ServerFuncBtns)).menu, isTrue);
    await tester.tap(find.byTooltip('工具')); await frames(tester);
    for (final text in [libL10n.process, app_locale.l10n.services, libL10n.portForward, app_locale.l10n.power]) {
      expect(find.text(text), findsWidgets);
    }
    await capture(tester, 'tools');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  void clearHistory() {
    // Replace the test snapshot before the provider builds; production FIFO
    // buffers deliberately cannot be resized through the List interface.
    server.snapshot = server.snapshot.copyWith(status: fixture.observedStatus());
  }

  testWidgets('detail tool menu fits large text on a narrow phone', (tester) async {
    await pump(tester, 'detail', size: const Size(320, 740), scale: 2);
    await tester.tap(find.byTooltip('工具')); await frames(tester);
    await capture(tester, 'tools-audit-large');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('tools dialog scrolls with a fixed close button and returns only a selection', (tester) async {
    await pump(tester, 'detail');
    final selected = showDialog<ServerFuncBtn>(
      context: tester.element(find.byType(ServerDetailPage)),
      builder: (_) => ServerToolsDialog(serverName: spi.name, items: ServerFuncBtn.values));
    await frames(tester);
    final close = find.byKey(const ValueKey('floating-dialog-close'));
    final before = tester.getTopLeft(close);
    final last = find.byKey(const ValueKey('server-tool-scheduledTasks'));
    await tester.ensureVisible(last); await frames(tester);
    expect(tester.getTopLeft(close), before);
    await tester.tap(last); await frames(tester);
    expect(await selected, ServerFuncBtn.scheduledTasks);
    expect(find.byType(ServerToolsDialog), findsNothing);
    expect(find.byType(ServerDetailPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('server-tools-button'))); await frames(tester);
    await tester.tap(close); await frames(tester);
    expect(find.byType(ServerToolsDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('tools dialog follows dark theme and fits landscape', (tester) async {
    for (final size in [const Size(393, 852), const Size(740, 320)]) {
      await pump(tester, 'detail', size: size, dark: true);
      if (size.width < 600) {
        await tester.tap(find.byKey(const ValueKey('server-tools-button')));
      } else {
        // The wider detail layout retains its existing horizontal tool bar.
        showDialog<ServerFuncBtn>(context: tester.element(find.byType(ServerDetailPage)),
          builder: (_) => ServerToolsDialog(serverName: spi.name, items: ServerFuncBtn.values));
      }
      await frames(tester);
      expect(find.byType(ServerToolsDialog), findsOneWidget);
      await capture(tester, size.height > size.width ? 'tools-dark' : 'tools-landscape');
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      final theme = Theme.of(tester.element(find.byType(ServerToolsDialog)));
      expect(theme.brightness, Brightness.dark);
      expect(dialog.backgroundColor, theme.colorScheme.surfaceContainerLow);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('floating-dialog-close'))); await frames(tester);
      await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
    }
  });

  testWidgets('detail charts preserve gaps and irregular sampling times', (tester) async {
    clearHistory();
    final h = server.snapshot.status.history;
    final start = DateTime(2026, 10, 1, 16).millisecondsSinceEpoch;
    final values = <double?>[12, null, 15, double.nan, 60];
    for (var i = 0; i < values.length; i++) {
      h.add(timeMs: start + [0, 3000, 6000, 9000, 39000][i], cpu: values[i], mem: 36);
    }
    await pump(tester, 'detail');
    final chart = tester.widget<LineChart>(find.byType(LineChart).first);
    final line = chart.data.lineBarsData.single;
    expect(line.spots.where((s) => !s.isNull()).map((s) => s.y), [12, 15, 60]);
    expect(line.spots.where((s) => !s.isNull()).map((s) => s.x), [0, 6, 39]);
    expect(line.spots.where((s) => s.isNull()), hasLength(2));
    final item = chart.data.lineTouchData.touchTooltipData.getTooltipItems(
      [LineBarSpot(line, 0, line.spots.last)]).single!;
    expect(item.text, contains('CPU  60%'));
    expect(item.children!.single.text, '\n16:00:39');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('detail charts label the measured network series when receive is missing', (tester) async {
    clearHistory();
    Stores.setting.detailCardOrder.put(['net']);
    final h = server.snapshot.status.history;
    server.snapshot.status.netSpeed.update([
      NetSpeedPart('eth0', BigInt.zero, BigInt.from(1024), 1),
    ]);
    h.add(timeMs: DateTime(2026, 10, 1, 16).millisecondsSinceEpoch, netTx: 1024);
    h.add(timeMs: DateTime(2026, 10, 1, 16, 0, 3).millisecondsSinceEpoch, netTx: 2048);
    await pump(tester, 'detail');
    final chart = tester.widget<LineChart>(find.byType(LineChart).first);
    final line = chart.data.lineBarsData.single;
    final item = chart.data.lineTouchData.touchTooltipData.getTooltipItems(
      [LineBarSpot(line, 0, line.spots.last)]).single!;
    expect(item.text, startsWith('↑'));
    expect(item.text, isNot(startsWith('↓')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('detail chart renders a single sample without invented history', (tester) async {
    clearHistory();
    server.snapshot.status.history.add(
      timeMs: DateTime(2026, 10, 1, 16).millisecondsSinceEpoch, cpu: 100, mem: 36);
    await pump(tester, 'detail');
    final chart = tester.widget<LineChart>(find.byType(LineChart).first);
    expect(chart.data.lineBarsData.single.spots, [const FlSpot(0, 100)]);
    expect(chart.data.maxX, greaterThan(chart.data.minX));
    expect(chart.data.maxY, greaterThan(chart.data.minY));
    await tester.tap(find.byType(LineChart).first);
    await frames(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('detail charts fit enlarged text after scrolling on a small phone', (tester) async {
    await pump(tester, 'detail', size: const Size(320, 740), scale: 1.5);
    final list = find.descendant(of: find.byType(ServerDetailPage), matching: find.byType(ListView)).first;
    await tester.drag(list, const Offset(0, -680)); await frames(tester);
    expect(find.byType(LineChart), findsWidgets);
    expect(tester.takeException(), isNull);
    await capture(tester, 'detail-chart-large');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('process list preserves CPU values and details', (tester) async {
    await pump(tester, 'process');
    expect(find.text('1.7%'), findsOneWidget);
    await tester.tap(find.text('nginx')); await frames(tester);
    expect(find.text('PID: 1245'), findsOneWidget);
    expect(find.text('CPU: 1.7%'), findsOneWidget);
    await capture(tester, 'process-details');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('service scope filters select the actual user units', (tester) async {
    await pump(tester, 'services');
    await tester.tap(find.widgetWithText(FilterChip, libL10n.user)); await frames(tester);
    expect(find.text('gpg-agent'), findsOneWidget);
    expect(find.text('nginx'), findsNothing);
    await capture(tester, 'services-user');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('empty forward CTA opens dynamic rule creation', (tester) async {
    await pump(tester, 'forward');
    await tester.tap(find.text('添加规则')); await frames(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('SOCKS5').last); await frames(tester);
    expect(find.byType(TextField), findsNWidgets(3));
    await capture(tester, 'forward-add');
    await tester.enterText(find.byType(TextField).at(0), 'SOCKS fixture');
    await tester.enterText(find.byType(TextField).at(1), '127.0.0.1');
    await tester.enterText(find.byType(TextField).at(2), '1080');
    await tester.tap(find.text(libL10n.ok)); await frames(tester);
    final saved = Stores.portForward.fetchForServer(spi.id).single;
    expect(saved.type, PortForwardType.dynamic);
    expect(saved.remoteHost, isNull);
    expect(saved.localPort, 1080);
    expect(find.text('SOCKS fixture'), findsOneWidget);
    await capture(tester, 'forward-saved');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('mobile editor saves changed fields with original credentials', (tester) async {
    await pump(tester, 'editor');
    final host = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '43.138.167.180');
    await tester.enterText(host, '192.0.2.42');
    await tester.tap(find.text(libL10n.save)); await frames(tester);
    final saved = Stores.server.fetch().firstWhere((server) => server.id == spi.id);
    expect(saved.ssh?.ip, '192.0.2.42');
    expect(saved.ssh?.pwd, 'fixture-password');
    expect(find.text(libL10n.save), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('process PID sorting remains functional', (tester) async {
    await pump(tester, 'process');
    await tester.tap(find.byIcon(Icons.sort)); await frames(tester);
    await tester.tap(find.text('PID').last); await frames(tester);
    expect(tester.getTopLeft(find.text('systemd')).dy, lessThan(tester.getTopLeft(find.text('nginx')).dy));
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });

  testWidgets('forward creation fits a small phone with enlarged text', (tester) async {
    await pump(tester, 'forward', size: const Size(320, 740), scale: 1.5);
    await tester.ensureVisible(find.text('添加规则'));
    await tester.tap(find.text('添加规则')); await frames(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('SOCKS5')); await frames(tester);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await capture(tester, 'forward-add-large');
    await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
  });
}

/// Exercise form validation and SQLite persistence without opening a connection
/// or scheduling cloud backups after changing a fixture address.
class _PageServers extends ServersNotifier {
  _PageServers(this.spi);
  final Spi spi;
  @override
  ServersState build() => ServersState(servers: {spi.id: spi}, serverOrder: [spi.id]);
  @override
  Future<void> updateServer(Spi old, Spi next) async {
    Stores.server.update(old, next);
    state = state.copyWith(servers: {next.id: next}, serverOrder: [next.id]);
  }
}

class _PageServer extends ServerNotifier {
  _PageServer(this.snapshot);
  ServerState snapshot;
  final exec = _ProcessExec();
  @override
  ServerState build(String serverId) => snapshot;
  @override
  Future<ServerExec> ensureScriptExec() async => exec;
  @override
  Future<ServerExec> ensureExec() async => exec;
}

class _ProcessExec implements ServerExec {
  @override
  Future<ExecResult> run(String script, {String? entry, Map<String, String>? env,
    String? stdin, OnExecOutput? onStdout, OnExecOutput? onStderr, Future<void>? cancel}) async => const ExecResult(
    exitCode: 0, stderr: '', stdout: '''PID USER %CPU %MEM VSZ RSS COMMAND
1245 root 1.7 2.1 1024 512 nginx
892 root 0.8 1.5 1024 512 containerd
766 root 0.6 0.9 1024 512 sshd
1 root 0.3 0.4 1024 512 systemd
3421 ubuntu 0.2 0.6 1024 512 python
3180 ubuntu 0.1 0.8 1024 512 node
2870 mysql 0.1 1.2 1024 512 mysqld
2543 redis 0.0 0.7 1024 512 redis-server
''');
}

class _PageServices extends ServicesNotifier {
  @override
  ServicesState build(spi) => ServicesState(manager: ServiceManagerType.systemd, units: [
    for (final name in ['dbus','nginx','ssh','gpg-agent','dirmngr','dev-hugepages','dev-mqueue']) ServiceUnit(
      name: name, type: name == 'nginx' || name == 'ssh' ? ServiceUnitType.service : ServiceUnitType.socket,
      scope: name == 'gpg-agent' || name == 'dirmngr' ? ServiceScope.user : ServiceScope.system,
      state: ServiceState.running, actions: const [ServiceAction.status, ServiceAction.restart, ServiceAction.stop]),
  ]);
  @override
  Future<void> getServices() async {}
}
