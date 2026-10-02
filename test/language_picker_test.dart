import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/localizations.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/language_picker.dart';

void main() {
  Future<void> open(WidgetTester tester, {Size size = const Size(393, 852),
    double scale = 1, double keyboard = 0, bool dark = false,
    ValueChanged<Locale?>? result}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
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
        onPressed: () async {
          final selected = await showLanguagePicker(context, initial: const Locale('zh'));
          result?.call(selected);
        }, child: const Text('Open')))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('search aliases find languages and Done returns the selected locale', (tester) async {
    Locale? selection;
    await open(tester, result: (value) => selection = value);
    final rect = tester.getRect(find.byKey(const ValueKey('language-picker')));
    expect(rect.left, greaterThan(0));
    expect(rect.top, greaterThan(0));
    await tester.enterText(find.byType(EditableText), '繁体');
    await tester.pump();
    expect(find.byKey(const ValueKey('language-zh_TW')), findsOneWidget);
    expect(find.byKey(const ValueKey('language-en')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('language-zh_TW')));
    await tester.pump();
    expect(selection, isNull);
    await tester.tap(find.byKey(const ValueKey('language-done')));
    await tester.pumpAndSettle();
    expect(selection, const Locale('zh', 'TW'));
    expect(find.byKey(const ValueKey('language-picker')), findsNothing);
  });

  testWidgets('empty search and closing leave the current language unchanged', (tester) async {
    Locale? selection;
    await open(tester, result: (value) => selection = value);
    await tester.enterText(find.byType(EditableText), 'no-language-match');
    await tester.pump();
    expect(find.text(libL10n.empty), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('language-close')));
    await tester.pumpAndSettle();
    expect(selection, isNull);
  });

  for (final scenario in [
    (const Size(320, 640), 1.6, 0.0),
    (const Size(393, 852), 1.0, 320.0),
    (const Size(852, 393), 1.0, 160.0),
    (const Size(852, 393), 1.6, 160.0),
  ]) {
    testWidgets('floating picker fits ${scenario.$1} with keyboard ${scenario.$3}', (tester) async {
      await open(tester, size: scenario.$1, scale: scenario.$2,
        keyboard: scenario.$3, dark: true, result: (_) {});
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('language-done')), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'en');
      await tester.pump();
      expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
