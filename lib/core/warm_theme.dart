import 'package:flutter/material.dart';

/// Motion shared by the warm mobile shell. Accessibility settings always win.
abstract final class WarmMotion {
  static const quick = Duration(milliseconds: 140);
  static const page = Duration(milliseconds: 240);

  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : duration;

  static AnimationStyle dialog(BuildContext context) => AnimationStyle(
    duration: of(context, page),
    reverseDuration: of(context, quick),
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
}

/// A shorter route on the warm phone UI; Material keeps the native back gesture.
class WarmPageRoute<T> extends MaterialPageRoute<T> {
  WarmPageRoute({
    required super.builder,
    super.settings,
    required this.reduceMotion,
  });

  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : WarmMotion.page;

  @override
  Duration get reverseTransitionDuration => transitionDuration;
}

class WarmPage<T> extends MaterialPage<T> {
  const WarmPage({required super.child, super.key});

  @override
  Route<T> createRoute(BuildContext context) => WarmPageRoute<T>(
    builder: (_) => child,
    settings: this,
    reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations == true,
  );
}

/// Keeps both phone destinations mounted, while only the visible one ticks.
class WarmPersistentTabStack extends StatelessWidget {
  const WarmPersistentTabStack({
    super.key,
    required this.settingsOpen,
    required this.home,
    required this.settings,
  });

  final bool settingsOpen;
  final Widget home;
  final Widget settings;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: settingsOpen ? 1 : 0,
    children: [
      TickerMode(enabled: !settingsOpen, child: home),
      TickerMode(enabled: settingsOpen, child: settings),
    ],
  );
}

/// Shared mobile geometry and a restrained, system-like palette.
/// Existing names are retained so business-facing pages need no rewrite.
abstract final class WarmTheme {
  static const canvas = Color(0xfff5f6f8);
  static const surface = Color(0xffffffff);
  static const surfaceStrong = Color(0xffedf0f5);
  static const peach = Color(0xffe7efff);
  static const copper = Color(0xff2563eb);
  static const ink = Color(0xff172033);
  static const muted = Color(0xff697386);
  static const olive = Color(0xff16834a);
  static const lemon = Color(0xffedf7ec);
  static const danger = Color(0xffdc3545);
  static const pagePadding = 18.0;
  static const cardRadius = 22.0;
  static const controlRadius = 16.0;
  static const sectionGap = 16.0;
  static const cardPadding = 18.0;

  /// Phone-only control geometry. Desktop keeps its existing density/layout.
  static ThemeData mobilePolish(ThemeData base) {
    final scheme = base.colorScheme;
    return base.copyWith(
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static ThemeData light({Color seedColor = copper, ColorScheme? colorScheme}) {
    final accent = colorScheme ?? ColorScheme.fromSeed(seedColor: seedColor,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    final scheme = accent.copyWith(
      secondary: olive,
      onSecondary: Colors.white,
      secondaryContainer: lemon,
      onSecondaryContainer: ink,
      error: danger,
      onError: Colors.white,
      surface: canvas,
      onSurface: ink,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceStrong,
      surfaceContainerHighest: surfaceStrong,
      outline: Color(0xffbbc3cf),
      outlineVariant: Color(0xffe3e7ee),
      shadow: Color(0x22000000),
      scrim: Color(0xaa172033),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(cardRadius)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: const Color(0xfff5f6f8),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: ink,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.primary : muted,
            size: 24,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Color(0xfff5f6f8),
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(34)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 2),
        minLeadingWidth: 32,
        horizontalTitleGap: 12,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(color: muted, fontSize: 12, height: 1.25),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xffedf0f5),
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: Color(0xffe3e7ee)),
        shape: StadiumBorder(),
        labelStyle: TextStyle(color: ink, fontSize: 11),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xffe3e7ee),
        thickness: 1,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primaryContainer,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: .12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xff8893a4),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : const Color(0xffe3e7ee),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0xffaab3c1)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: ink,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: ink, fontSize: 16),
        bodyMedium: TextStyle(color: ink, fontSize: 14),
        bodySmall: TextStyle(color: muted, fontSize: 12),
      ),
    );
  }

  static ThemeData dark({Color seedColor = copper, ColorScheme? colorScheme}) {
    final geometry = light(seedColor: seedColor);
    final scheme = colorScheme ?? ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: geometry.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface).copyWith(
        bodySmall: geometry.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      appBarTheme: geometry.appBarTheme.copyWith(
        backgroundColor: scheme.surface, foregroundColor: scheme.onSurface,
        titleTextStyle: geometry.appBarTheme.titleTextStyle?.copyWith(color: scheme.onSurface)),
      cardTheme: geometry.cardTheme.copyWith(color: scheme.surfaceContainerLow),
      navigationBarTheme: geometry.navigationBarTheme.copyWith(
        backgroundColor: scheme.surfaceContainer, indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: scheme.onSurface, fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(size: 24,
          color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant))),
      navigationRailTheme: geometry.navigationRailTheme.copyWith(
        backgroundColor: scheme.surfaceContainer, indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant)),
      dialogTheme: geometry.dialogTheme.copyWith(backgroundColor: scheme.surfaceContainerHigh),
      bottomSheetTheme: geometry.bottomSheetTheme.copyWith(backgroundColor: scheme.surfaceContainerLow),
      listTileTheme: geometry.listTileTheme.copyWith(
        titleTextStyle: geometry.listTileTheme.titleTextStyle?.copyWith(color: scheme.onSurface),
        subtitleTextStyle: geometry.listTileTheme.subtitleTextStyle?.copyWith(color: scheme.onSurfaceVariant)),
      chipTheme: geometry.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow, selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: geometry.chipTheme.labelStyle?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer, fontSize: 11)),
      dividerTheme: geometry.dividerTheme.copyWith(color: scheme.outlineVariant),
      sliderTheme: geometry.sliderTheme.copyWith(
        activeTrackColor: scheme.primary, inactiveTrackColor: scheme.primaryContainer,
        thumbColor: scheme.primary, overlayColor: scheme.primary.withValues(alpha: .12)),
    );
  }

  /// AMOLED changes surfaces, retaining the same control geometry and text
  /// styles so internal Material animations can interpolate safely.
  static ThemeData amoled(ThemeData base) => base.copyWith(
    scaffoldBackgroundColor: Colors.black, canvasColor: Colors.black,
    colorScheme: base.colorScheme.copyWith(surface: Colors.black),
    appBarTheme: base.appBarTheme.copyWith(backgroundColor: Colors.black),
    navigationBarTheme: base.navigationBarTheme.copyWith(backgroundColor: Colors.black),
    navigationRailTheme: base.navigationRailTheme.copyWith(backgroundColor: Colors.black),
    drawerTheme: base.drawerTheme.copyWith(backgroundColor: Colors.black),
  );
}
