import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/warm_theme.dart';

void main() {
  testWidgets('phone motion follows reduced-motion preference', (tester) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    expect(WarmMotion.of(pageContext, WarmMotion.page), WarmMotion.page);
    expect(
      WarmPageRoute<void>(
        builder: (_) => const Scaffold(),
        reduceMotion: false,
      ).transitionDuration,
      WarmMotion.page,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    expect(WarmMotion.of(pageContext, WarmMotion.page), Duration.zero);
    expect(
      WarmPageRoute<void>(
        builder: (_) => const Scaffold(),
        reduceMotion: true,
      ).transitionDuration,
      Duration.zero,
    );
  });

  testWidgets('switching destinations preserves both page states', (
    tester,
  ) async {
    final settingsOpen = ValueNotifier(false);
    addTearDown(settingsOpen.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: settingsOpen,
          builder: (_, open, _) => WarmPersistentTabStack(
            settingsOpen: open,
            home: const _CounterPane('home'),
            settings: const _CounterPane('settings'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home: 0'));
    await tester.pump();
    expect(find.text('home: 1'), findsOneWidget);

    settingsOpen.value = true;
    await tester.pump();
    await tester.tap(find.text('settings: 0'));
    await tester.pump();
    expect(find.text('settings: 1'), findsOneWidget);
    expect(find.text('home: 1'), findsNothing);

    settingsOpen.value = false;
    await tester.pump();
    expect(find.text('home: 1'), findsOneWidget);
    settingsOpen.value = true;
    await tester.pump();
    expect(find.text('settings: 1'), findsOneWidget);
  });
}

class _CounterPane extends StatefulWidget {
  const _CounterPane(this.label);

  final String label;

  @override
  State<_CounterPane> createState() => _CounterPaneState();
}

class _CounterPaneState extends State<_CounterPane> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => setState(() => count++),
        child: Text('${widget.label}: $count'),
      ),
    ),
  );
}
