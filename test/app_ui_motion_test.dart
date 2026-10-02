import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/view/widget/app_ui.dart';

void main() {
  Widget host(Widget child, {bool reduceMotion = false, bool dark = false}) =>
      MaterialApp(
        theme: dark ? WarmTheme.dark() : WarmTheme.light(),
        localizationsDelegates: const [FLocalizations.delegate],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: AppUiScope(child: child!),
        ),
        home: Scaffold(body: child),
      );

  testWidgets('monitor refresh preserves the entrance and focused child state', (tester) async {
    final reading = ValueNotifier(1);
    final controller = TextEditingController(text: 'typed host');
    final focus = FocusNode();
    addTearDown(reading.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(host(ValueListenableBuilder(
      valueListenable: reading,
      builder: (_, value, _) => AppEntrance(child: Column(children: [
        Text('$value%'),
        FTextField(control: FTextFieldControl.managed(controller: controller), focusNode: focus),
      ])),
    )));
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();
    final entrance = find.descendant(of: find.byType(AppEntrance), matching: find.byType(Animate));
    final animationState = tester.state(entrance);
    final inputState = tester.state(find.byType(EditableText));
    reading.value = 42;
    await tester.pump();
    expect(tester.state(entrance), same(animationState));
    expect(tester.state(find.byType(EditableText)), same(inputState));
    expect(focus.hasFocus, isTrue);
    expect(controller.text, 'typed host');
    expect(find.text('42%'), findsOneWidget);
    final fade = tester.widget<FadeTransition>(find.descendant(
      of: entrance, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.text = 'still owned by the page';
  });

  testWidgets('reduced motion shows measurements immediately without effect tickers', (tester) async {
    await tester.pumpWidget(host(const AppEntrance(child: AppValueText('42%')), reduceMotion: true));
    expect(find.byType(Animate), findsNothing);
    expect(find.text('42%'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('ForUI controls use the same dark palette and retain button actions', (tester) async {
    var presses = 0;
    await tester.pumpWidget(host(AppCard(child: AppButton(
      onPressed: () => presses++, child: const Text('Connect'),
    )), dark: true));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(FButton));
    expect(FTheme.of(context).colors.primary, Theme.of(context).colorScheme.primary);
    expect(FTheme.of(context).colors.foreground, Theme.of(context).colorScheme.onSurface);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(presses, 1);
  });
}
