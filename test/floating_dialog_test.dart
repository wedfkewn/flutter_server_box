import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/localizations.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/app_dialog.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/floating_dialog.dart';

void main() {
  final capture = GlobalKey();
  setUpAll(() async {
    final path = r'C:\Windows\Fonts\msyh.ttc';
    if (File(path).existsSync()) {
      final bytes = await File(path).readAsBytes();
      await (FontLoader('DialogSans')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final bytes = await File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes();
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  Future<void> open(WidgetTester tester, Future<void> Function(BuildContext) action,
    {Size size = const Size(393, 852), double keyboard = 0, double scale = 1, bool dark = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final theme = dark ? WarmTheme.dark() : WarmTheme.light();
    await tester.pumpWidget(RepaintBoundary(key: capture, child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'DialogSans')),
      locale: const Locale('zh'), supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [FLocalizations.delegate, LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates],
      builder: (context, child) {
        context.setLibL10n();
        return MediaQuery(data: MediaQuery.of(context).copyWith(
          viewInsets: EdgeInsets.only(bottom: keyboard), textScaler: TextScaler.linear(scale)),
          child: AppUiScope(child: child!));
      },
      home: Builder(builder: (context) => Scaffold(appBar: AppBar(title: const Text('通用')),
        body: TextButton(onPressed: () => action(context), child: const Text('打开')))),
    )));
    await tester.tap(find.text('打开'));
    await tester.pump(const Duration(milliseconds: 300));
  }
  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final boundary = capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('design-qa/floating-dialogs/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('single selection searches and returns a value, cancellation returns null', (tester) async {
    String? result;
    await open(tester, (ctx) async { result = await ctx.showAppPickSingleDialog<String>(
      title: '字体', items: ['自动', '黑体', 'Arial', 'Roboto', 'Menlo', 'Monaco', 'Consolas', 'Noto Sans', 'Ubuntu Mono']); });
    await shot(tester, 'font-light');
    await tester.enterText(find.byKey(const ValueKey('dialog-choice-search')), '黑体');
    await tester.pump();
    expect(find.text('Consolas'), findsNothing);
    await tester.tap(find.widgetWithText(AppDialogChoiceRow<String>, '黑体'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, '黑体');
    await open(tester, (ctx) async { result = await ctx.showAppPickSingleDialog<String>(title: '主题模式', items: ['自动', '亮', '暗']); });
    await tester.tap(find.byKey(const ValueKey('floating-dialog-close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, isNull);
  });

  testWidgets('multi selection commits only with OK and does not mutate supplied actions', (tester) async {
    List<String>? result;
    final actions = <Widget>[];
    await open(tester, (ctx) async { result = await ctx.showAppPickDialog<String>(
      title: '服务检测', items: ['ChatGPT', 'Netflix', 'Gemini', 'YouTube'], initial: ['ChatGPT'], actions: actions); }, dark: true);
    await tester.tap(find.text('Netflix'));
    await tester.pump();
    expect(result, isNull);
    expect(actions, isEmpty);
    await shot(tester, 'services-dark');
    await tester.tap(find.text(libL10n.ok));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, containsAll(['ChatGPT', 'Netflix']));
  });

  testWidgets('confirmation and locked dialog preserve route results and dismissal', (tester) async {
    bool? result;
    await open(tester, (ctx) async { result = await ctx.showAppRoundDialog<bool>(
      title: '删除服务器？', child: const Text('删除后将移除服务器配置。'),
      actionsBuilder: (dialog) => [TextButton(onPressed: () => dialog.popDialog(false), child: const Text('取消')),
        FilledButton(onPressed: () => dialog.popDialog(true), child: const Text('删除'))]); });
    await shot(tester, 'confirmation-light');
    await tester.tap(find.text('取消'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, false);
    await open(tester, (ctx) async { await ctx.showAppRoundDialog<void>(title: '正在连接',
      barrierDismiss: false, child: const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()))); });
    expect(find.byKey(const ValueKey('floating-dialog-close')), findsNothing);
    await tester.tapAt(const Offset(8, 8));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppFloatingDialog), findsOneWidget);
  });

  testWidgets('locked progress dialog cannot be dismissed with system back', (tester) async {
    await open(tester, (ctx) async { await ctx.showAppRoundDialog<void>(
      title: '正在连接', barrierDismiss: false, child: const Text('请稍候')); });
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'locked-system-back');
    expect(find.byType(AppFloatingDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(AppFloatingDialog))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppFloatingDialog), findsNothing);
  });

  testWidgets('close button dismisses the navigator that owns the dialog', (tester) async {
    await open(tester, (ctx) async { await showDialog<void>(context: ctx,
      builder: (_) => Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (inner) => Scaffold(body: TextButton(onPressed: () => showDialog<void>(
          context: inner, useRootNavigator: false,
          builder: (_) => const AppFloatingDialog(title: Text('嵌套弹窗'))), child: const Text('Nested')))))); });
    await tester.tap(find.text('Nested'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('floating-dialog-close')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nested'), findsOneWidget);
    expect(find.byType(AppFloatingDialog), findsNothing);
  });

  for (final config in [(const Size(320, 640), 0.0, 1.6), (const Size(393, 852), 320.0, 1.0), (const Size(852, 393), 160.0, 1.0)]) {
    testWidgets('input scrolls with keyboard and large text $config', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await open(tester, (ctx) async { await ctx.showAppRoundDialog<String>(title: '连接服务器',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, decoration: const InputDecoration(labelText: '密码')),
          const SizedBox(height: 12), const Text('请输入服务器密码，以连接并获取监控数据。'),
          for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.all(10), child: Text('更多连接说明')),
        ]), actionsBuilder: (dialog) => [FilledButton(onPressed: () => dialog.popDialog(controller.text), child: const Text('连接'))]); },
        size: config.$1, keyboard: config.$2, scale: config.$3);
      expect(tester.takeException(), isNull);
      if (config.$2 == 320) await shot(tester, 'input-keyboard');
      await tester.tap(find.text('连接'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AppFloatingDialog), findsNothing);
    });
  }
}
