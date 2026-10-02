import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/theme_reveal.dart';

void main() {
  setUpAll(() async {
    final file = File(Platform.isWindows ? r'C:\Windows\Fonts\msyh.ttc'
      : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      await (FontLoader('ThemePreview')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  ThemeData preview(ThemeData value) => value.copyWith(
    textTheme: value.textTheme.apply(fontFamily: 'ThemePreview'),
    primaryTextTheme: value.primaryTextTheme.apply(fontFamily: 'ThemePreview'));
  test('seed controls accents without tinting the neutral light surfaces', () {
    const red = Color(0xffd32f2f), green = Color(0xff278438);
    final a = WarmTheme.light(seedColor: red), b = WarmTheme.light(seedColor: green);
    expect(a.colorScheme.primary, isNot(b.colorScheme.primary));
    expect(a.scaffoldBackgroundColor, b.scaffoldBackgroundColor);
    expect(a.navigationBarTheme.indicatorColor, a.colorScheme.primaryContainer);
    expect(a.switchTheme.trackColor?.resolve({WidgetState.selected}), a.colorScheme.primary);
    expect(a.sliderTheme.thumbColor, a.colorScheme.primary);
    expect(WarmTheme.dark(seedColor: red).colorScheme.primary,
      isNot(WarmTheme.dark(seedColor: green).colorScheme.primary));
  });

  test('reveal removes the old theme from the top-right towards bottom-left', () {
    const size = Size(390, 844);
    final start = ThemeRevealClipper(const AlwaysStoppedAnimation(0)).getClip(size);
    expect(start.contains(const Offset(2, 842)), isTrue);
    final middle = ThemeRevealClipper(const AlwaysStoppedAnimation(.5)).getClip(size);
    expect(middle.contains(const Offset(388, 2)), isFalse);
    expect(middle.contains(const Offset(2, 842)), isTrue);
    final end = ThemeRevealClipper(const AlwaysStoppedAnimation(1)).getClip(size);
    expect(end.contains(const Offset(2, 842)), isFalse);
  });

  late ValueNotifier<ThemeData> theme;
  late TextEditingController input;
  late FocusNode focus;
  late BuildContext pageContext;
  late GlobalKey captureKey;
  late ThemeRevealObserver observer;
  var builds = 0;

  setUp(() {
    theme = ValueNotifier(preview(WarmTheme.light()));
    input = TextEditingController(text: 'ubuntu@server');
    focus = FocusNode();
    captureKey = GlobalKey();
    observer = ThemeRevealObserver();
    builds = 0;
  });
  tearDown(() { theme.dispose(); input.dispose(); focus.dispose(); });

  Future<void> pump(WidgetTester tester, {bool reduced = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ValueListenableBuilder(valueListenable: theme,
      builder: (_, value, _) => MaterialApp(theme: value, themeAnimationDuration: Duration.zero,
        localizationsDelegates: const [FLocalizations.delegate],
        navigatorObservers: [observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: RepaintBoundary(key: captureKey, child: ThemeReveal(
            theme: Theme.of(context), observer: observer, child: AppUiScope(child: child!))),
        ),
        home: Builder(builder: (context) {
          pageContext = context;
          builds++;
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('ServerBox', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              AppCard(padding: const EdgeInsets.all(18), child: Column(children: [
                Text('CPU 24% · Memory 36%', style: TextStyle(color: scheme.primary)),
                const SizedBox(height: 16), TextField(controller: input, focusNode: focus),
                const SizedBox(height: 16), AppButton(onPressed: () {}, child: const Text('Connect')),
              ])),
            ]))),
          );
        }),
      )));
    await tester.pumpAndSettle();
  }

  Future<void> change(WidgetTester tester, ThemeData next) async {
    final future = ThemeReveal.change(pageContext, () => theme.value = preview(next));
    for (var i = 0; i < 4; i++) { await tester.pump(); }
    await future;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('design-qa/theme-reveal')..createSync(recursive: true);
      await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('one reveal keeps input state and does not rebuild the page per frame', (tester) async {
    await pump(tester);
    focus.requestFocus();
    await tester.pump();
    final field = tester.state(find.byType(EditableText));
    await capture(tester, '01-light');
    await change(tester, WarmTheme.dark());
    expect(find.byType(RawImage), findsOneWidget);
    final afterSwitch = builds;
    await tester.pump(const Duration(milliseconds: 210));
    await capture(tester, '02-expanding');
    for (var i = 0; i < 5; i++) { await tester.pump(const Duration(milliseconds: 16)); }
    expect(builds, afterSwitch);
    expect(tester.state(find.byType(EditableText)), same(field));
    expect(input.text, 'ubuntu@server');
    expect(focus.hasFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RawImage), findsNothing);
    await capture(tester, '03-dark');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion switches immediately and shares the ForUI seed', (tester) async {
    await pump(tester, reduced: true);
    final next = WarmTheme.light(seedColor: const Color(0xff278438));
    await change(tester, next);
    expect(find.byType(RawImage), findsNothing);
    expect(FTheme.of(tester.element(find.byType(FButton))).colors.primary, next.colorScheme.primary);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rapid switches, unchanged selection and resize leave no snapshot', (tester) async {
    await pump(tester);
    await change(tester, WarmTheme.dark());
    await tester.pump(const Duration(milliseconds: 60));
    await change(tester, WarmTheme.light(seedColor: const Color(0xffd32f2f)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RawImage), findsNothing);
    await change(tester, theme.value);
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);
    await change(tester, WarmTheme.dark());
    tester.view.physicalSize = const Size(844, 390);
    await tester.pump();
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dismissed picker finishes before its page is captured', (tester) async {
    await pump(tester);
    showDialog<void>(context: pageContext, builder: (_) => const AlertDialog(content: Text('Theme picker')));
    await tester.pumpAndSettle();
    Navigator.of(pageContext).pop();
    final future = ThemeReveal.change(pageContext, () => theme.value = WarmTheme.dark());
    await tester.pump();
    expect(theme.value.brightness, Brightness.light);
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 5; i++) { await tester.pump(); }
    await future;
    expect(find.text('Theme picker'), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
