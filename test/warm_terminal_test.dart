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
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/ssh/tab.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:xterm/ui.dart';

import 'helpers/fake_shell.dart';
import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();

  setUpAll(() async {
    Paths.doc = Directory('.tools/terminal-capture').absolute.path;
    Directory(Paths.doc).createSync(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async =>
              const StandardMessageCodec().encodeMessage(<Object?>[null]),
        );
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
    await loadFont('consola.ttf', r'C:\Windows\Fonts\consola.ttf');
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
    getIt.registerSingleton<SettingStore>(SettingStore('warm_terminal_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<HistoryStore>(
      HistoryStore('terminal_capture_history'),
    );
    getIt.registerSingleton<ServerDistStore>(ServerDistStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(
      SelfAddrStore('terminal_capture_addr'),
    );
    getIt.registerSingleton<AgentConversationStore>(AgentConversationStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.setting.sshTermHelpShown.put(true);
    Stores.setting.termFontSize.put(14);
    Stores.setting.fontPath.put(r'C:\Windows\Fonts\consola.ttf');
    Stores.server.put(
      spiFixture(
        id: 'backup',
        name: '备用服务器',
        ip: '192.0.2.20',
        user: 'root',
        autoConnect: false,
      ),
    );
    Stores.server.put(
      spiFixture(
        id: 'terminal-capture',
        name: '123',
        ip: '192.0.2.10',
        user: 'ubuntu',
        autoConnect: false,
      ),
    );
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
    Widget child = const SSHTabPage(),
    ProviderContainer? container,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    // Match the real app's persisted theme choice as well as its ThemeData.
    Stores.setting.themeMode.put(dark ? 2 : 1);
    final theme = dark ? ThemeData.dark() : WarmTheme.light();
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: UncontrolledProviderScope(
          container: container ?? ProviderContainer(),
          child: MaterialApp(
            key: ValueKey('accordion-$size-$textScale-$dark'),
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh'),
            localizationsDelegates: const [
              FLocalizations.delegate,
              LibLocalizations.delegate,
              ...AppLocalizations.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme.copyWith(
              listTileTheme: theme.listTileTheme.copyWith(
                titleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
                  fontFamily: 'SettingsSans',
                ),
                subtitleTextStyle: theme.listTileTheme.titleTextStyle?.copyWith(
                  fontFamily: 'SettingsSans',
                ),
              ),
              appBarTheme: theme.appBarTheme.copyWith(
                titleTextStyle: const TextStyle(
                  fontFamily: 'SettingsSans',
                  fontSize: 18,
                  color: WarmTheme.ink,
                ),
              ),
              textTheme: theme.textTheme.apply(fontFamily: 'SettingsSans'),
              primaryTextTheme: theme.primaryTextTheme.apply(
                fontFamily: 'SettingsSans',
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: AppUiScope(child: ResponsivePoints.builder(context, child)),
            ),
            home: Builder(
              builder: (context) {
                app_locale.l10n = AppLocalizations.of(context)!;
                context.setLibL10n();
                // Home owns this navigation. Reproduce its NavigationBar
                // configuration here to capture the settings in its real
                // available body height, without launching server/FFI setup.
                return Scaffold(
                  body: child,
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: 1,
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

  Future<(ProviderContainer, TerminalSession)> connected(
    WidgetTester tester, {
    Size size = const Size(390, 848),
    double textScale = 1,
    bool dark = false,
    bool running = true,
  }) async {
    final spi = Stores.server.fetch().firstWhere(
      (e) => e.id == 'terminal-capture',
    );
    final session = TerminalSession(
      source: ServerSource(spi),
      backend: FakeShellBackend(),
    );
    if (running) session.bindForeground((await session.openShell())!);
    session.terminal.write(
      '\x1b[32mubuntu@123\x1b[0m:~\$ uname -s\r\nLinux\r\n\x1b[32mubuntu@123\x1b[0m:~\$ pwd\r\n/home/ubuntu\r\n\x1b[32mubuntu@123\x1b[0m:~\$ ',
    );
    final container = ProviderContainer();
    container
        .read(terminalRequestsProvider.notifier)
        .add(spi, session: session);
    await pump(
      tester,
      container: container,
      size: size,
      textScale: textScale,
      dark: dark,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      container.dispose();
    });
    return (container, session);
  }

  testWidgets('drawer preserves the connected shell and input', (tester) async {
    final (_, session) = await connected(tester);
    expect(find.text('已连接'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('terminal-connections-drawer')),
      findsNothing,
    );
    final state = tester.state<SSHPageState>(find.byType(SSHPage));
    await capture(tester, 'terminal-redesign-collapsed.png');
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    expect(find.text('当前会话'), findsOneWidget);
    expect(find.text('新建连接'), findsOneWidget);
    expect(find.byType(TerminalView), findsOneWidget);
    expect(
      identical(tester.state<SSHPageState>(find.byType(SSHPage)), state),
      isTrue,
    );
    await capture(tester, 'terminal-redesign-expanded.png');
    await tester.tap(find.byKey(const ValueKey('terminal-collapse-drawer')));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('terminal-connections-drawer')),
      findsNothing,
    );
    expect(identical(state.session, session), isTrue);
    session.terminal.onOutput?.call('echo alive\n');
    expect(
      (session.foreground as FakeShellSession).written.toString(),
      contains('echo alive'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the handle collapses without replacing the shell', (tester) async {
    final (_, session) = await connected(tester);
    final page = tester.state<SSHPageState>(find.byType(SSHPage));
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    final terminal = find.byType(TerminalView);
    final initialHeight = tester.getSize(terminal).height;
    final gesture = await tester.startGesture(tester.getCenter(
      find.byKey(const ValueKey('terminal-drawer-handle'))));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getSize(terminal).height, greaterThan(initialHeight));
    expect(tester.state<SSHPageState>(find.byType(SSHPage)), same(page));
    await capture(tester, 'terminal-drawer-dragging.png');
    await gesture.up();
    await settle(tester);
    expect(find.byKey(const ValueKey('terminal-connections-drawer')), findsNothing);
    expect(page.session, same(session));
    await capture(tester, 'terminal-drawer-drag-closed.png');
    session.terminal.onOutput?.call('echo after-drag\n');
    expect((session.foreground as FakeShellSession).written.toString(),
      contains('echo after-drag'));
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    expect(find.text('当前会话'), findsOneWidget);
    await tester.drag(find.descendant(
      of: find.byKey(const ValueKey('terminal-connections-drawer')),
      matching: find.byType(ListView)), const Offset(0, -80));
    await settle(tester);
    expect(find.byKey(const ValueKey('terminal-connections-drawer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short slow drag and a cancelled drag return the panel', (tester) async {
    await connected(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    final handle = find.byKey(const ValueKey('terminal-drawer-handle'));
    final top = tester.getTopLeft(handle).dy;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 24),
      timeStamp: const Duration(milliseconds: 100));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20),
      timeStamp: const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.getTopLeft(handle).dy - top, closeTo(44, .5));
    await gesture.up(timeStamp: const Duration(milliseconds: 800));
    await settle(tester);
    expect(tester.getTopLeft(handle).dy, closeTo(top, .5));
    final cancelled = await tester.startGesture(tester.getCenter(handle));
    await cancelled.moveBy(const Offset(0, 100));
    await tester.pump();
    await cancelled.cancel();
    await settle(tester);
    expect(tester.getTopLeft(handle).dy, closeTo(top, .5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a quick downward flick closes the panel', (tester) async {
    await connected(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    await tester.fling(find.byKey(const ValueKey('terminal-drawer-handle')),
      const Offset(0, 55), 1000);
    await settle(tester);
    expect(find.byKey(const ValueKey('terminal-connections-drawer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters connections without hiding open sessions', (
    tester,
  ) async {
    await connected(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    await tester.tap(find.byTooltip(libL10n.search));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '192.0.2.20');
    await settle(tester);
    expect(
      find.byKey(const ValueKey('terminal-connect-backup')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('terminal-connect-terminal-capture')),
      findsNothing,
    );
    expect(find.text('当前会话'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'no-match');
    await settle(tester);
    expect(find.text('当前会话'), findsOneWidget);
    expect(find.byKey(const ValueKey('terminal-session-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finished adopted output is labelled disconnected', (
    tester,
  ) async {
    await connected(tester, running: false);
    expect(find.text('已断开'), findsOneWidget);
    expect(find.text('已连接'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching sessions preserves both shells', (tester) async {
    final (container, first) = await connected(tester);
    final spi = Stores.server.fetch().firstWhere((e) => e.id == 'backup');
    final second = TerminalSession(
      source: ServerSource(spi),
      backend: FakeShellBackend(),
    );
    second.bindForeground((await second.openShell())!);
    container.read(terminalRequestsProvider.notifier).add(spi, session: second);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-session-0')));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('terminal-connections-drawer')),
      findsNothing,
    );
    expect(find.text('ubuntu@192.0.2.10:22'), findsOneWidget);
    expect(first.foreground, isNotNull);
    expect(second.foreground, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing a session keeps confirmation and saved tab state', (
    tester,
  ) async {
    await connected(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
    await settle(tester);
    await tester.tap(find.byTooltip('${libL10n.close} 123'));
    await settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(Dialog))).pop(false);
    await settle(tester);
    expect(find.byKey(const ValueKey('terminal-session-0')), findsOneWidget);
    await tester.tap(find.byTooltip('${libL10n.close} 123'));
    await settle(tester);
    await tester.tap(find.text(libL10n.ok));
    await settle(tester);
    expect(find.text('暂无会话'), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('terminal-drawer-handle')),
      const Offset(0, 150));
    await settle(tester);
    expect(find.byKey(const ValueKey('terminal-connections-drawer')), findsOneWidget);
    expect(Stores.history.sshTabs.fetch(), '[]');
    expect(find.byType(TerminalView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overflow retains tools and history', (tester) async {
    await connected(tester);
    await tester.tap(find.byKey(const ValueKey('terminal-tools-menu')));
    await settle(tester);
    expect(find.text(app_locale.l10n.askAi), findsOneWidget);
    expect(find.text(libL10n.snippet), findsOneWidget);
    expect(find.text(libL10n.sort), findsOneWidget);
    await tester.tap(find.text(app_locale.l10n.serverHistory));
    await settle(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('123'), findsAtLeastNWidgets(1));
    await tester.tap(find.text(libL10n.ok));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (const Size(320, 568), 2.0, false, 'large-text'),
    (const Size(568, 320), 1.0, false, 'landscape'),
    (const Size(390, 848), 1.0, true, 'dark'),
  ]) {
    testWidgets('drawer adapts to ${scenario.$4}', (tester) async {
      await connected(
        tester,
        size: scenario.$1,
        textScale: scenario.$2,
        dark: scenario.$3,
      );
      await tester.tap(find.byKey(const ValueKey('terminal-session-picker')));
      await settle(tester);
      await capture(tester, 'terminal-redesign-${scenario.$4}.png');
      expect(
        find.byKey(const ValueKey('terminal-collapse-drawer')),
        findsOneWidget,
      );
      await tester.drag(find.byKey(const ValueKey('terminal-drawer-handle')),
        const Offset(0, 120));
      await settle(tester);
      expect(find.byKey(const ValueKey('terminal-connections-drawer')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty terminal offers the actual saved connections', (
    tester,
  ) async {
    final container = ProviderContainer();
    await pump(tester, container: container);
    expect(find.text('暂无会话'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('terminal-connect-terminal-capture')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('terminal-connect-backup')),
      findsOneWidget,
    );
    await capture(tester, 'terminal-redesign-picker.png');
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    container.dispose();
    expect(tester.takeException(), isNull);
  });
}
