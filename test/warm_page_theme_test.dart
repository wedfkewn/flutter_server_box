import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/view/widget/theme_reveal.dart';

void main() {
  testWidgets('updated mobile pages preserve pop transitions and reduced motion', (tester) async {
    for (final reduced in [false, true]) {
      final showDetail = ValueNotifier(false);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(data: MediaQueryData(disableAnimations: reduced),
          child: ValueListenableBuilder<bool>(valueListenable: showDetail,
            builder: (context, detail, _) => Navigator(key: navigator, pages: [
              const WarmPage<void>(key: ValueKey('root'), child: Scaffold(body: Text('root'))),
              if (detail) const WarmPage<void>(key: ValueKey('detail'), child: Scaffold(body: Text('detail'))),
            ], onDidRemovePage: (_) => showDetail.value = false))),
      ));
      await tester.pumpAndSettle();
      showDetail.value = true;
      await tester.pumpAndSettle();
      final route = ModalRoute.of(tester.element(find.text('detail')))!;
      expect(route.transitionDuration, reduced ? Duration.zero : WarmMotion.page);
      expect(route.reverseTransitionDuration, route.transitionDuration);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      expect(find.text('detail'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      showDetail.dispose();
    }
  });

  testWidgets('retained mobile page refreshes its opaque background in both theme directions', (tester) async {
    final theme = ValueNotifier(WarmTheme.light());
    final field = GlobalKey();
    const surface = ValueKey('mobile-page-surface');
    final navKey = GlobalKey<NavigatorState>();
    addTearDown(theme.dispose);
    await tester.pumpWidget(ValueListenableBuilder<ThemeData>(
      valueListenable: theme,
      builder: (_, data, _) => MaterialApp(
        theme: data, themeAnimationDuration: Duration.zero,
        builder: (context, child) => ThemeReveal(theme: Theme.of(context), child: child!),
        home: Builder(builder: (context) => Navigator(
          key: navKey,
          pages: [WarmPage<void>(key: const ValueKey('settings'),
            child: Material(key: surface, color: Theme.of(context).scaffoldBackgroundColor,
              child: TextField(key: field))),
          ],
          onDidRemovePage: (_) {},
        )),
      ),
    ));
    await tester.pumpAndSettle();
    final nav = navKey.currentState;
    final state = field.currentState;
    await tester.enterText(find.byType(TextField), 'preserved input');
    for (final next in [WarmTheme.dark(), WarmTheme.light(),
      WarmTheme.amoled(WarmTheme.dark()), WarmTheme.light(seedColor: Colors.green)]) {
      theme.value = next;
      await tester.pumpAndSettle();
      expect(tester.widget<Material>(find.byKey(surface)).color, next.scaffoldBackgroundColor);
      expect(navKey.currentState, same(nav));
      expect(field.currentState, same(state));
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text ??
        tester.state<EditableTextState>(find.byType(EditableText)).widget.controller.text, 'preserved input');
      expect(find.byType(RawImage), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
