import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/dot_matrix_loader.dart';

void main() {
  Widget host({
    bool enabled = true,
    bool reduced = false,
    double width = 320,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TickerMode(
        enabled: enabled,
        child: Center(
          child: SizedBox(
            width: width,
            child: const Row(
              children: [
                DotMatrixLoader(
                  label: '正在检测公网 IP',
                  style: DotMatrixStyle.orbit,
                ),
                DotMatrixLoader(label: '正在查询 IP'),
                DotMatrixLoader(label: '正在解析 DNS', style: DotMatrixStyle.scan),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('delays paint, keeps bounds, and cancels short requests', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final bounds = tester.getSize(find.byType(DotMatrixLoader).first);
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.bySemanticsLabel('正在查询 IP'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.bySemanticsLabel('正在查询 IP'), findsOneWidget);
    expect(tester.getSize(find.byType(DotMatrixLoader).first), bounds);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('hidden and reduced-motion loaders stop scheduling frames', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(host(enabled: false));
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(host(reduced: true));
    expect(find.bySemanticsLabel('正在解析 DNS'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(host(width: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background pauses and resume restarts animation', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 160));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });
}
