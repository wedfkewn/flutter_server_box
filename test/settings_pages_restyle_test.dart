import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/localizations.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/brand_icons.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/page/setting/platform/ios.dart';
import 'package:server_box/view/page/setting/seq/srv_detail_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';
import 'package:server_box/view/page/setting/seq/srv_orders.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final captureKey = GlobalKey();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('settings-restyle-');
    Paths.doc = temp.path;
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    await LinuxDistros.loadBundled();
    Future<void> font(String family, String path) async {
      if (!File(path).existsSync()) return;
      final bytes = await File(path).readAsBytes();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await font('SettingsSans', Platform.isWindows ? r'C:\Windows\Fonts\msyh.ttc'
      : '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    await font('SettingsLatin', r'C:\Windows\Fonts\segoeui.ttf');
    await font('SettingsKorean', r'C:\Windows\Fonts\malgun.ttf');
    final configFile = File('.dart_tool/package_config.json').absolute;
    final packages = (jsonDecode(await configFile.readAsString()) as Map)['packages'] as List;
    final icons = packages.cast<Map>().firstWhere((package) => package['name'] == 'icons_plus');
    final fonts = configFile.uri.resolve(icons['rootUri'] as String).resolve('assets/fonts/');
    for (final file in Directory.fromUri(fonts).listSync().whereType<File>()) {
      if (file.path.endsWith('.ttf')) {
        final family = file.uri.pathSegments.last.replaceAll('.ttf', '');
        await font('packages/icons_plus/$family', file.path);
      }
    }
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) await font('MaterialIcons', '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  });
  setUp(() async {
    await openTestDb();
    FlutterSecureStorage.setMockInitialValues({});
    getIt.registerSingleton<SettingStore>(SettingStore('settings_restyle'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
  });
  tearDown(() async { await getIt.reset(); await closeTestDb(); });
  tearDownAll(() => temp.delete(recursive: true));

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) { await tester.pump(const Duration(milliseconds: 50)); }
  }
  Future<void> pump(WidgetTester tester, Widget page, String title, {
    double width = 393, double scale = 1, bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 852);
    final theme = dark ? WarmTheme.dark() : WarmTheme.light();
    await tester.pumpWidget(RepaintBoundary(key: captureKey, child: ProviderScope(
      child: MaterialApp(key: ValueKey('$title-$width-$scale-$dark'), debugShowCheckedModeBanner: false,
        locale: const Locale('zh'), supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [FLocalizations.delegate, LibLocalizations.delegate, ...AppLocalizations.localizationsDelegates],
        theme: theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'SettingsSans', fontFamilyFallback: ['SettingsLatin', 'SettingsKorean']),
          primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'SettingsSans'),
          appBarTheme: theme.appBarTheme.copyWith(titleTextStyle:
            theme.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'SettingsSans'))),
        builder: (context, child) => AppUiScope(child: ResponsivePoints.builder(context, MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!))),
        home: Builder(builder: (context) {
          context.setLibL10n(); app_locale.l10n = AppLocalizations.of(context)!;
          return Scaffold(appBar: AppBar(leading: BackButton(onPressed: () {}),
            title: Text(title), centerTitle: true, actions: const [Icon(Icons.more_vert), SizedBox(width: 16)]),
            body: page, bottomNavigationBar: NavigationBar(selectedIndex: 2, destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '控制台'),
              NavigationDestination(icon: Icon(Icons.terminal), label: '终端'),
              NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
            ]));
        })))));
    await frames(tester);
  }
  Future<void> capture(WidgetTester tester, String name) => tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('design-qa/settings-pages').createSync(recursive: true);
    await File('design-qa/settings-pages/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });

  testWidgets('language popup matches the floating design and saves only on Done', (tester) async {
    for (final dark in [false, true]) {
      await pump(tester, const AppSettingsPage(section: SettingsSection.app), '通用', dark: dark);
      await tester.tap(find.text(libL10n.language).first);
      await frames(tester);
      expect(find.byKey(const ValueKey('language-picker')), findsOneWidget);
      final rect = tester.getRect(find.byKey(const ValueKey('language-picker')));
      expect(rect.left, greaterThan(20));
      expect(rect.top, greaterThan(40));
      await capture(tester, 'language-floating-${dark ? "dark" : "light"}');
      await tester.enterText(find.byType(EditableText), '英语');
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('language-en')));
      await frames(tester);
      expect(Stores.setting.locale.fetch(), isNot('en'));
      await tester.tap(find.byKey(const ValueKey('language-done')));
      await frames(tester);
      expect(Stores.setting.locale.fetch(), 'en');
      expect(find.byType(AppSettingsPage), findsOneWidget);
      Stores.setting.locale.put('zh');
      expect(tester.takeException(), isNull);
    }
  });

  final pages = <String, Widget>{
    'iOS': const IosSettingsPage(embedded: true),
    'AI': const AppSettingsPage(section: SettingsSection.ai),
    '导入': const BackupPage(section: BackupSection.import),
    '同步': const BackupPage(section: BackupSection.sync),
    '隐私': const AppSettingsPage(section: SettingsSection.privacy),
    '编辑器': const AppSettingsPage(section: SettingsSection.editor),
    '容器': const AppSettingsPage(section: SettingsSection.container),
    'SFTP': const AppSettingsPage(section: SettingsSection.sftp),
    '服务器设置': const AppSettingsPage(section: SettingsSection.server),
    '终端设置': const AppSettingsPage(section: SettingsSection.ssh),
    '顺序': const ServerOrdersPage(embedded: true),
    '详情卡片': const ServerDetailOrderPage(embedded: true),
    '功能按钮': const ServerFuncBtnsOrderPage(embedded: true),
  };
  testWidgets('server groups preserve every existing row and open global program rules', (tester) async {
    await pump(tester, const AppSettingsPage(section: SettingsSection.server), '服务器设置');
    expect(find.text('程序图标'), findsOneWidget);
    expect(find.text('服务器管理'), findsOneWidget);
    expect(find.text(app_locale.l10n.netViewType), findsOneWidget);
    expect(find.text(app_locale.l10n.connectionStats), findsOneWidget);
    await tester.tap(find.text('程序图标'));
    await frames(tester);
    expect(find.byType(BrandIconsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all selected settings pages render and capture without layout errors', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    for (final entry in pages.entries) {
      await pump(tester, entry.value, entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
      await capture(tester, entry.key);
      await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('all pages remain usable at 320 pixels with larger text and dark mode', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    for (final dark in [false, true]) {
      for (final entry in pages.entries) {
        await pump(tester, entry.value, entry.key, width: 320, scale: 1.3, dark: dark);
        expect(tester.takeException(), isNull, reason: '${entry.key} dark=$dark');
        if (entry.key == 'AI' || entry.key == '编辑器') {
          await capture(tester, '${entry.key}-${dark ? 'dark' : 'large'}');
        }
        await tester.pumpWidget(const SizedBox.shrink()); await frames(tester);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('switches still save settings and detail labels keep their stable keys', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await pump(tester, pages['容器']!, '容器');
    final before = Stores.setting.usePodman.fetch();
    await tester.tap(find.byType(Switch).first); await frames(tester);
    expect(Stores.setting.usePodman.fetch(), !before);
    await pump(tester, const ServerDetailOrderPage(embedded: true), '详情卡片');
    expect(find.text('内存'), findsOneWidget); expect(find.text('about'), findsNothing);
    final disabled = Stores.setting.detailCardDisabled.fetch();
    await capture(tester, '详情卡片');
    await tester.tap(find.byType(Checkbox).first); await frames(tester);
    expect(Stores.setting.detailCardDisabled.fetch().contains('about'), !disabled.contains('about'));
    await pump(tester, const ServerFuncBtnsOrderPage(embedded: true), '功能按钮');
    final buttons = List<int>.from(Stores.setting.serverFuncBtns.fetch());
    await capture(tester, '功能按钮');
    await tester.tap(find.byType(Checkbox).first); await frames(tester);
    expect(Stores.setting.serverFuncBtns.fetch().length, buttons.length - 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag handles reorder detail cards and enabled tools', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await pump(tester, const ServerDetailOrderPage(embedded: true), '详情卡片');
    final details = List<String>.from(Stores.setting.detailCardOrder.fetch());
    var gesture = await tester.startGesture(tester.getCenter(find.byType(ReorderableDragStartListener).first));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20)); await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 110)); await frames(tester);
    await gesture.up();
    await frames(tester);
    expect(Stores.setting.detailCardOrder.fetch().first, details[1]);
    await pump(tester, const ServerFuncBtnsOrderPage(embedded: true), '功能按钮');
    final tools = List<int>.from(Stores.setting.serverFuncBtns.fetch());
    gesture = await tester.startGesture(tester.getCenter(find.byType(ReorderableDragStartListener).first));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 20)); await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 110)); await frames(tester);
    await gesture.up();
    await frames(tester);
    expect(Stores.setting.serverFuncBtns.fetch().first, tools[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long font names and encrypted backup controls fit on small screens', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    Stores.setting.editorFontFamily.put('A very long custom monospace font family');
    Stores.setting.fontPath.put('/fonts/A very long custom monospace font family.ttf');
    for (final name in ['编辑器', '终端设置']) {
      await pump(tester, pages[name]!, name, width: 320, scale: 1.3);
      expect(tester.takeException(), isNull, reason: name);
    }
    await SecureStoreProps.bakPwd.write('test-backup-password');
    await pump(tester, pages['同步']!, '同步', width: 320, scale: 1.3);
    expect(find.text('备份已加密'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real settings navigation exposes logs and reset inside the overflow menu', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await pump(tester, const SettingsPage(), '设置导航');
    await tester.tap(find.byKey(const ValueKey('warm-category-toggle-files'))); await frames(tester);
    await tester.tap(find.text('编辑器')); await frames(tester);
    expect(find.text('文字与排版'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>)); await frames(tester);
    expect(find.text('日志'), findsOneWidget);
    expect(find.text('重置所有设置'), findsOneWidget);
    await tester.tapAt(const Offset(8, 400)); await frames(tester);
    await tester.tap(find.byType(BackButton).last); await frames(tester);
    expect(find.text('编辑器'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
