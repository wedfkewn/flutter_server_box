import 'dart:async';
import 'dart:math' as math;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:forui/localizations.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart' as dynamic_material show ColorScheme;
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/diagnostics_upload.dart';
import 'package:server_box/core/warm_theme.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/home.dart';
import 'package:server_box/view/widget/app_ui.dart';
import 'package:server_box/view/widget/diagnostics_level_picker.dart';
import 'package:server_box/view/widget/theme_reveal.dart';

part 'intro.dart';

Widget _buildHomeWithWindowFrame() {
  return VirtualWindowFrame(title: BuildData.name, child: const HomePage());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<List<IntroPageBuilder>> _introFuture = _IntroPage.builders;
  late final Listenable _appListenable = Listenable.merge([
    RNodes.app,
    Stores.setting.locale.listenable(),
    Stores.setting.themeMode.listenable(),
    Stores.setting.colorSeed.listenable(),
    Stores.setting.useSystemPrimaryColor.listenable(),
  ]);
  final _themeObserver = ThemeRevealObserver();
  Color? _cachedSeed;
  ColorScheme? _cachedSystemLight, _cachedSystemDark;
  late ThemeData _lightTheme, _darkTheme;
  bool _transparentNavBarConfigured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_transparentNavBarConfigured) return;
    _transparentNavBarConfigured = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemUIs.setTransparentNavigationBar(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appListenable,
      builder: (context, _) {
        return _buildDynamicColor(context);
      },
    );
  }

  Widget _buildPalette(BuildContext context, {ColorScheme? systemLight, ColorScheme? systemDark}) {
    final seed = Color(Stores.setting.colorSeed.fetch());
    if (_cachedSeed != seed || _cachedSystemLight != systemLight || _cachedSystemDark != systemDark) {
      _cachedSeed = seed;
      _cachedSystemLight = systemLight;
      _cachedSystemDark = systemDark;
      _lightTheme = WarmTheme.light(seedColor: seed, colorScheme: systemLight);
      _darkTheme = WarmTheme.dark(seedColor: seed, colorScheme: systemDark);
    }
    final mode = Stores.setting.themeMode.fetch();
    final dark = mode == 2 || mode == 3 || ((mode == 0 || mode == 4) &&
      (MediaQuery.maybePlatformBrightnessOf(context) ??
        View.of(context).platformDispatcher.platformBrightness) == Brightness.dark);
    UIs.colorSeed = seed;
    UIs.primaryColor = (dark ? _darkTheme : _lightTheme).colorScheme.primary;
    return _buildApp(context, light: _lightTheme, dark: _darkTheme);
  }

  Widget _buildDynamicColor(BuildContext context) {
    return DynamicColorBuilder(
      builder: (light, dark) {
        if (!Stores.setting.useSystemPrimaryColor.fetch()) return _buildPalette(context);
        return _buildPalette(context, systemLight: light == null ? null : _systemPalette(light),
          systemDark: dark == null ? null : _systemPalette(dark));
      },
    );
  }

  ColorScheme _systemPalette(dynamic_material.ColorScheme source) => ColorScheme(
    brightness: source.brightness, primary: source.primary, onPrimary: source.onPrimary,
    primaryContainer: source.primaryContainer, onPrimaryContainer: source.onPrimaryContainer,
    secondary: source.secondary, onSecondary: source.onSecondary,
    secondaryContainer: source.secondaryContainer, onSecondaryContainer: source.onSecondaryContainer,
    tertiary: source.tertiary, onTertiary: source.onTertiary,
    tertiaryContainer: source.tertiaryContainer, onTertiaryContainer: source.onTertiaryContainer,
    error: source.error, onError: source.onError,
    errorContainer: source.errorContainer, onErrorContainer: source.onErrorContainer,
    surface: source.surface, onSurface: source.onSurface,
    onSurfaceVariant: source.onSurfaceVariant, outline: source.outline,
    outlineVariant: source.outlineVariant, shadow: source.shadow, scrim: source.scrim,
    inverseSurface: source.inverseSurface, onInverseSurface: source.onInverseSurface,
    inversePrimary: source.inversePrimary,
  );

  Widget _buildApp(
    BuildContext ctx, {
    required ThemeData light,
    required ThemeData dark,
  }) {
    final tMode = Stores.setting.themeMode.fetch();
    // Issue #57
    final themeMode = switch (tMode) {
      1 || 2 => ThemeMode.values[tMode],
      3 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final locale = Stores.setting.locale.fetch().toLocale;

    return MaterialApp(
      key: ValueKey(locale),
      restorationScopeId: 'serverbox',
      navigatorKey: AppNavigator.key,
      // It sits over the top-right corner, which is where every page's app bar
      // keeps its actions — and it says nothing a debug build does not already
      // say everywhere else.
      debugShowCheckedModeBanner: false,
      // Outside the breakpoints builder: a toast is sized against the window,
      // not against the scaled layout the breakpoints hand to the pages.
      builder: (ctx, child) {
        UIs.primaryColor = Theme.of(ctx).colorScheme.primary;
        return ThemeReveal(theme: Theme.of(ctx), observer: _themeObserver,
          child: AppUiScope(child: ToastHost(child: ResponsivePoints.builder(ctx, child))));
      },
      locale: locale,
      localizationsDelegates: const [
        FLocalizations.delegate,
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      navigatorObservers: [AppRouteObserver.instance, _themeObserver],
      title: BuildData.name,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      theme: (isMobile ? WarmTheme.mobilePolish(light) : light).fixWindowsFont,
      darkTheme:
          (isMobile
                  ? WarmTheme.mobilePolish(tMode < 3 ? dark : WarmTheme.amoled(dark))
                  : (tMode < 3 ? dark : WarmTheme.amoled(dark)))
              .fixWindowsFont,
      home: FutureBuilder<List<IntroPageBuilder>>(
        future: _introFuture,
        builder: (context, snapshot) {
          context.setLibL10n();
          final appL10n = AppLocalizations.of(context);
          if (appL10n != null) l10n = appL10n;

          Widget child;
          var hasWindowFrame = false;
          if (snapshot.connectionState == ConnectionState.waiting) {
            child = const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            final intros = snapshot.data ?? [];
            if (intros.isNotEmpty) {
              child = _IntroPage(intros);
            } else {
              child = _buildHomeWithWindowFrame();
              hasWindowFrame = true;
            }
          }

          if (hasWindowFrame) return child;
          return VirtualWindowFrame(title: BuildData.name, child: child);
        },
      ),
    );
  }
}
