import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/text_edit_menu.dart';

void main() {
  testWidgets('editing toolbar stays compact above the keyboard on iOS', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        return null;
      });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
    final controller = TextEditingController(text: '154.9.254.212');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1.3)), child: child!),
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(24),
        child: TextField(controller: controller, contextMenuBuilder: buildAppTextEditMenu))),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 300));
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 13);
    await tester.pump();
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.showToolbar();
    await tester.pump(const Duration(milliseconds: 300));
    final toolbar = find.byType(TextSelectionToolbar);
    expect(toolbar, findsOneWidget);
    final surface = find.descendant(of: toolbar, matching: find.byType(Material)).first;
    expect(tester.getSize(surface).height, lessThan(100));
    expect(tester.getRect(surface).bottom, lessThanOrEqualTo(440));
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(controller.text, '154.9.254.212');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
