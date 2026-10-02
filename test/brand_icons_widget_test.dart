import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/brand_icons.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/brand_logo.dart';
import 'package:server_box/view/widget/dist_icon.dart';

import 'helpers/test_db.dart';

void main() {
  setUpAll(() async {
    final font = File(Platform.isWindows ? r'C:\Windows\Fonts\msyh.ttc' : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (font.existsSync()) {
      final bytes = await font.readAsBytes();
      await (FontLoader('BrandPreview')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('brand_widgets')..init());
  });
  tearDown(() async { await getIt.reset(); await closeTestDb(); });

  Widget app(Widget home, {bool dark = false, double scale = 1}) => MaterialApp(
    theme: (dark ? WarmTheme.dark() : WarmTheme.light()).copyWith(textTheme:
      (dark ? WarmTheme.dark() : WarmTheme.light()).textTheme.apply(fontFamily: 'BrandPreview')),
    localizationsDelegates: const [FLocalizations.delegate],
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: AppUiScope(child: child!)), home: home,
  );

  testWidgets('custom process rule saves, edits, deletes and immediately changes the icon', (tester) async {
    await tester.pumpWidget(app(const BrandIconsPage()));
    await tester.tap(find.text('Add rule').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).first, 'my-api');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(Stores.setting.processLogoMap.fetch(), {'my-api': 'python'});
    expect(Stores.setting.serviceLogoMap.fetch(), isEmpty);
    await tester.tap(find.text('my-api'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextFormField).first, 'my-worker');
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(Stores.setting.processLogoMap.fetch(), {'my-worker': 'python'});
    await tester.tap(find.byTooltip('Delete rule'));
    await tester.pump();
    expect(Stores.setting.processLogoMap.fetch(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme-safe native colors, fixed geometry and reactive overrides', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: Column(children: [
      DistIconOf(Dist.ubuntu, size: 24),
      ProgramLogo('my-api'), ProgramLogo('nginx.service', service: true, type: ServiceUnitType.service),
    ])), dark: true));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SvgPicture), findsNWidgets(2));
    for (final picture in tester.widgetList<SvgPicture>(find.byType(SvgPicture))) {
      expect(picture.colorFilter, isNull);
    }
    Stores.setting.processLogoMap.put({'my-api': 'python'});
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SvgPicture), findsNWidgets(3));
    expect(tester.getSize(find.byType(ProgramLogo).first), const Size(24, 24));
    Stores.setting.showProgramLogos.put(false);
    await tester.pump();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.getSize(find.byType(ProgramLogo).first), const Size(24, 24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow screen and large text keep rule editor within the viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const BrandIconsPage(), scale: 1.6));
    await tester.tap(find.text('Add rule').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextFormField).first, 'my-api');
    await tester.tap(find.text('Image URL'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, 'file:///logo.png');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(Stores.setting.processLogoMap.fetch(), isEmpty);
    expect(find.text('Enter a valid HTTPS image URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
  });
  testWidgets('logo badges stay aligned and single-tone marks contrast in both themes', (tester) async {
    tester.view.physicalSize = const Size(393, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    for (final dark in [false, true]) {
      await tester.pumpWidget(app(RepaintBoundary(key: capture, child: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ServerBox · 系统与程序图标', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            for (final row in [
              ['Ubuntu', 'Debian', 'Arch', 'Fedora'],
              ['Python', 'nginx', 'Docker', 'macOS'],
            ]) Padding(padding: const EdgeInsets.only(bottom: 24), child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (final name in row) SizedBox(width: 72, child: Column(children: [
                if (['Ubuntu', 'Debian', 'Arch', 'Fedora', 'macOS'].contains(name))
                  DistIconOf(switch (name) { 'Ubuntu' => Dist.ubuntu, 'Debian' => Dist.debian,
                    'Arch' => Dist.arch, 'Fedora' => Dist.fedora, _ => Dist.macos }, size: 44)
                else ProgramLogo(name.toLowerCase(), size: 44),
                const SizedBox(height: 8), Text(name, style: const TextStyle(fontSize: 12)),
              ]))],
            )),
          ],
        )),
      )), dark: dark));
      await tester.pumpAndSettle();
      final mac = find.descendant(of: find.byWidgetPredicate((w) => w is DistIconOf && w.dist == Dist.macos), matching: find.byType(SvgPicture));
      expect(tester.widget<SvgPicture>(mac).colorFilter, isNotNull);
      for (final badge in find.byType(BrandLogo).evaluate()) {
        expect(tester.getSize(find.byWidget(badge.widget)), const Size(44, 44));
      }
      await tester.runAsync(() async {
      final boundary = capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final picture = await boundary.toImage(pixelRatio: 2);
      final png = await picture.toByteData(format: ui.ImageByteFormat.png);
      final output = File('design-qa/brand-refresh-${dark ? "dark" : "light"}.png');
      await output.writeAsBytes(png!.buffer.asUint8List());
      picture.dispose();
      });
      expect(tester.takeException(), isNull);
    }
  });

}
