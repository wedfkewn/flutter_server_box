import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/localizations.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/res/command_reference.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/command_reference_dialog.dart';

void main() {
  Future<void> open(WidgetTester tester, {Size size = const Size(393, 852),
    double scale = 1, double keyboard = 0, bool dark = false,
    String language = 'zh', bool guide = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: Locale(language), supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [FLocalizations.delegate, LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates],
      theme: dark ? WarmTheme.dark() : WarmTheme.light(),
      builder: (context, child) {
        context.setLibL10n();
        return MediaQuery(data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale), viewInsets: EdgeInsets.only(bottom: keyboard)),
          child: AppUiScope(child: child!));
      },
      home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => showCommandReference(context, guide: guide), child: const Text('Open')))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  test('bundled catalog has 32 complete bilingual entries and search aliases', () {
    expect(commandReferences.length, 32);
    expect(commandReferences.map((e) => e.name).toSet().length, 32);
    for (final doc in commandReferences) {
      expect(doc.summary.$1, isNotEmpty); expect(doc.summary.$2, isNotEmpty);
      expect(doc.syntax, isNotEmpty); expect(doc.requirements.$1, isNotEmpty);
      expect(Uri.parse(doc.source).scheme, 'https');
      expect(doc.options, isNotEmpty); expect(doc.examples, isNotEmpty);
    }
    expect(commandReferences.where((e) => e.matches('监听')).map((e) => e.name), contains('ss'));
    expect(commandReferences.where((e) => e.matches('MEMORY')).map((e) => e.name), contains('free'));
  });

  testWidgets('offline search, detail back, copy feedback and close', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester);
    await tester.enterText(find.byType(EditableText), 'pwd');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('command-pwd')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('复制'));
    await tester.tap(find.text('复制'));
    await tester.pumpAndSettle();
    expect(copied, 'pwd -P'); expect(find.text('已复制'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('command-reference-back')));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, 'pwd');
    await tester.enterText(find.byType(EditableText), 'no-such-command');
    await tester.pumpAndSettle();
    expect(find.textContaining('没有匹配'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('command-reference-close')));
    await tester.pumpAndSettle();
    expect(find.byType(CommandReferenceDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('other languages fall back to English and guide only offers copying', (tester) async {
    await open(tester, language: 'de', guide: true);
    expect(find.text('Command highlighting guide'), findsOneWidget);
    expect(find.text('Fish · Built-in highlighting'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Bash'), 240, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('cannot provide complete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from a detail preserves the list scroll position and category', (tester) async {
    await open(tester);
    await tester.tap(find.text('网络与连接'));
    await tester.pumpAndSettle();
    final list = find.byKey(const PageStorageKey('command-reference-list'));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.descendant(of: list,
      matching: find.byType(Scrollable)).first).position.pixels;
    await tester.ensureVisible(find.byKey(const ValueKey('command-curl')));
    final saved = tester.state<ScrollableState>(find.descendant(of: list,
      matching: find.byType(Scrollable)).first).position.pixels;
    expect(position, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('command-curl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('command-reference-back')));
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(find.descendant(of: list,
      matching: find.byType(Scrollable)).first).position.pixels, saved);
    expect(find.byKey(const ValueKey('command-pwd')), findsNothing);
  });

  for (final scenario in [
    (const Size(320, 568), 2.0, 0.0, false),
    (const Size(393, 852), 1.0, 320.0, true),
    (const Size(852, 393), 1.6, 160.0, true),
  ]) {
    testWidgets('reference fits ${scenario.$1} large text and keyboard', (tester) async {
      await open(tester, size: scenario.$1, scale: scenario.$2,
        keyboard: scenario.$3, dark: scenario.$4);
      final rect = tester.getRect(find.byKey(const ValueKey('command-reference-surface')));
      expect(rect.width, lessThanOrEqualTo(560));
      expect(rect.left, greaterThanOrEqualTo(24));
      expect(rect.height, lessThanOrEqualTo(720));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('command-reference-close')));
      await tester.pumpAndSettle();
    });
  }
}
