import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/external_probe_controller.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/app/external_probe.dart';
import 'package:server_box/data/provider/external_probe.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/view/page/external_probes.dart';
import 'package:server_box/view/widget/external_probe_badges.dart';

import 'helpers/spi_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = 'probe-ui-fixture';
  late ExternalProbeController controller;
  final captureKey = GlobalKey();

  setUpAll(() async {
    for (final entry in {'WarmSans': r'C:\Windows\Fonts\msyh.ttc',
      'MaterialIcons': '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'}.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        await (FontLoader(entry.key)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    }
  });
  setUp(() {
    controller = ExternalProbeController(
      config: ProbeConfig(selected: {'google', 'github', 'youtube', 'netflix', 'chatGpt', 'gemini'},
        pinned: ['google', 'github', 'youtube', 'netflix']),
      save: (_) => true, readResult: (_) => null, writeResult: (_, _) {},
      runner: (targets) async => {for (final t in targets) t.id: ProbeResult(
        id: t.id, state: ProbeState.reachable, reason: 'httpResponse', checkedAt: DateTime.now())});
    for (final target in controller.config.enabled) {
      controller.results[target.id] = ProbeResult(id: target.id,
        state: target.id == 'netflix' ? ProbeState.rejected : ProbeState.reachable,
        reason: target.id == 'netflix' ? 'accessDenied' : 'httpResponse',
        checkedAt: DateTime.now(), httpStatus: target.id == 'netflix' ? 403 : 200,
        elapsedMs: 234, transport: 'SSH');
    }
  });
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, {Size size = const Size(393, 852),
    double scale = 1, bool dark = false, Widget? home}) async {
    tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final warm = dark ? WarmTheme.dark() : WarmTheme.light();
    await tester.pumpWidget(ProviderScope(overrides: [
      externalProbeProvider(id).overrideWith((ref) => controller),
      serverProvider(id).overrideWith(() => _UiServer()),
    ], child: RepaintBoundary(key: captureKey, child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh'), supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: warm.copyWith(textTheme: warm.textTheme.apply(fontFamily: 'WarmSans'),
        primaryTextTheme: warm.primaryTextTheme.apply(fontFamily: 'WarmSans'),
        appBarTheme: warm.appBarTheme.copyWith(titleTextStyle: warm.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'WarmSans')),
        listTileTheme: warm.listTileTheme.copyWith(
          titleTextStyle: warm.listTileTheme.titleTextStyle?.copyWith(fontFamily: 'WarmSans'),
          subtitleTextStyle: warm.listTileTheme.subtitleTextStyle?.copyWith(fontFamily: 'WarmSans')),
        chipTheme: warm.chipTheme.copyWith(labelStyle: warm.chipTheme.labelStyle?.copyWith(fontFamily: 'WarmSans'),
          secondaryLabelStyle: warm.chipTheme.labelStyle?.copyWith(fontFamily: 'WarmSans'))),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale)), child: child!),
      initialRoute: home == null ? '/checks' : '/',
      routes: {'/checks': (_) => const ExternalProbesPage(serverId: id)},
      home: home ?? const Scaffold()))));
    await tester.pump(const Duration(milliseconds: 300));
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) { await tester.pump(const Duration(milliseconds: 50)); }
  }

  Future<void> capture(WidgetTester tester, String name) => tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('design-qa').createSync(recursive: true);
    await File('design-qa/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });

  testWidgets('server center shows diagnostics and categories without claiming unlock', (tester) async {
    await pump(tester);
    expect(find.text('外网服务检测'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Google'), 150,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)));
    expect(find.text('Google'), findsOneWidget);
    await capture(tester, 'external-probes-center');
    await tester.tap(find.text('Google')); await frames(tester);
    expect(find.text('HTTP 200'), findsOneWidget);
    expect(find.text('请求耗时: 234 ms'), findsOneWidget);
    expect(find.textContaining('完整解锁'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, 'Netflix'); await frames(tester);
    expect(find.byKey(const ValueKey('probe-netflix')), findsOneWidget); expect(find.text('Google'), findsNothing);
    await tester.tap(find.text('Netflix').last); await frames(tester);
    expect(find.text('请求被拒绝，限制原因待确认'), findsOneWidget);
    expect(find.text('HTTP 403'), findsOneWidget);
  });

  testWidgets('management supports selection, pin limits and custom form save', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('管理检测项目')); await frames(tester);
    expect(find.byType(Checkbox), findsWidgets);
    await capture(tester, 'external-probes-manage');
    await tester.tap(find.text('添加自定义检测')); await frames(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'My API');
    await tester.enterText(find.byType(TextFormField).at(1), 'https://example.com/health');
    await capture(tester, 'external-probes-custom');
    await tester.tap(find.text('保存')); await frames(tester);
    expect(controller.config.custom.single.name, 'My API');
    expect(controller.config.selected, contains(controller.config.custom.single.id));
    expect(find.byType(AlertDialog), findsNothing); expect(tester.takeException(), isNull);
  });

  testWidgets('homepage exposes four pins and opens center with a working back button', (tester) async {
    await pump(tester, home: const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(20),
      child: ExternalProbeBadges(serverId: id)))));
    expect(find.byType(ActionChip), findsNWidgets(4));
    expect(find.text('Google · 网站响应'), findsOneWidget);
    await tester.tap(find.text('查看全部 ›')); await frames(tester);
    expect(find.text('外网服务检测'), findsOneWidget); expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton)); await frames(tester);
    expect(find.text('外网服务'), findsOneWidget); expect(tester.takeException(), isNull);
  });

  testWidgets('custom checkbox updates homepage even when four services are pinned', (tester) async {
    const custom = ProbeTarget(id: 'custom_home', name: 'My API',
      address: 'https://example.com/health', category: ProbeCategory.custom);
    controller.updateConfig(ProbeConfig(selected: controller.config.selected,
      pinned: controller.config.pinned, custom: [custom]));
    await pump(tester, home: const Scaffold(body: SafeArea(child: Padding(
      padding: EdgeInsets.all(20), child: ExternalProbeBadges(serverId: id)))));
    expect(find.byType(ActionChip), findsNWidgets(4));
    await tester.tap(find.text('查看全部 ›')); await frames(tester);
    await tester.enterText(find.byType(TextField).first, 'My API'); await frames(tester);
    await tester.tap(find.byType(Checkbox)); await frames(tester);
    expect(controller.config.homepageTargets.map((e) => e.id), contains('custom_home'));
    await tester.tap(find.byType(BackButton)); await frames(tester);
    expect(find.byType(ActionChip), findsNWidgets(4));
    await tester.tap(find.text('另有 1 项 · 展开')); await frames(tester);
    expect(find.byType(ActionChip), findsNWidgets(5));
    expect(find.textContaining('My API ·'), findsOneWidget);
    await tester.tap(find.text('查看全部 ›')); await frames(tester);
    await tester.enterText(find.byType(TextField).first, 'My API'); await frames(tester);
    await tester.tap(find.byType(Checkbox)); await frames(tester);
    await tester.tap(find.byType(BackButton)); await frames(tester);
    expect(find.byType(ActionChip), findsNWidgets(4));
    expect(find.textContaining('My API ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage truncates long names and labels expired results', (tester) async {
    final custom = ProbeTarget(id: 'custom_long', name: '自定义健康检查' * 10,
      address: 'https://example.com/health', category: ProbeCategory.custom);
    controller.updateConfig(ProbeConfig(selected: {'google', custom.id},
      pinned: ['google'], custom: [custom]));
    controller.results['google'] = ProbeResult(id: 'google', state: ProbeState.reachable,
      reason: 'httpResponse', checkedAt: DateTime.now().subtract(const Duration(days: 1)));
    await pump(tester, size: const Size(320, 740), scale: 1.3, dark: true,
      home: const Scaffold(body: Padding(padding: EdgeInsets.all(20),
        child: ExternalProbeBadges(serverId: id))));
    expect(find.text('Google · 结果过期'), findsOneWidget);
    expect(find.textContaining('未检测'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone center supports dark mode and enlarged text at 320 pixels', (tester) async {
    for (final dark in [false, true]) {
      await pump(tester, size: const Size(320, 740), scale: 1.3, dark: dark);
      await frames(tester);
      if (dark) {
        final context = tester.element(find.text('ChatGPT'));
        expect(DefaultTextStyle.of(context).style.color!.computeLuminance(), greaterThan(.5));
      }
      expect(tester.takeException(), isNull, reason: 'dark=$dark');
      await capture(tester, dark ? 'external-probes-dark' : 'external-probes-large');
    }
  });
}

class _UiServer extends ServerNotifier {
  @override
  ServerState build(String id) => ServerState(spi: spiFixture(id: id, name: 'Demo server', ip: 'example.invalid', autoConnect: false),
    status: InitStatus.status);
}
