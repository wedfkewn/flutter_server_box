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

/// The warm, low-contrast visual system used by the mobile ServerBox shell.
///
/// Kept in one place so cards, sheets, navigation and the terminal all share
/// the same paper-and-copper palette instead of carrying screenshot colours
/// as unrelated literals.
abstract final class WarmTheme {
  static const canvas = Color(0xfffffaf7);
  static const surface = Color(0xfffff2e8);
  static const surfaceStrong = Color(0xffffe7d5);
  static const peach = Color(0xffffd9bd);
  static const copper = Color(0xff955b24);
  static const ink = Color(0xff382f29);
  static const muted = Color(0xff7f7168);
  static const olive = Color(0xff68702c);
  static const lemon = Color(0xfffff69a);
  static const danger = Color(0xffbd2b22);
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
          shape: const StadiumBorder(),
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

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: copper,
      onPrimary: Colors.white,
      primaryContainer: peach,
      onPrimaryContainer: ink,
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
      surfaceContainerHighest: peach,
      outline: Color(0xffcdb7a6),
      outlineVariant: Color(0xffead8ca),
      shadow: Color(0x22000000),
      scrim: Color(0xaa1f1a17),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      splashColor: copper.withValues(alpha: 0.08),
      highlightColor: copper.withValues(alpha: 0.04),
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
        backgroundColor: const Color(0xfff8eee8),
        surfaceTintColor: Colors.transparent,
        indicatorColor: peach,
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
            color: states.contains(WidgetState.selected) ? copper : muted,
            size: 24,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xfff8eee8),
        indicatorColor: peach,
        selectedIconTheme: IconThemeData(color: copper),
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
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xffffeee2),
        selectedColor: peach,
        side: BorderSide(color: Color(0xffd5c0b1)),
        shape: StadiumBorder(),
        labelStyle: TextStyle(color: ink, fontSize: 11),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xffead8ca),
        thickness: 1,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: copper,
        inactiveTrackColor: peach,
        thumbColor: copper,
        overlayColor: Color(0x22955b24),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xff9a8a7d),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? copper
              : const Color(0xffffe4d1),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0xffa89282)),
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
        bodyLarge: TextStyle(color: ink, fontSize: 16),
        bodyMedium: TextStyle(color: ink, fontSize: 14),
        bodySmall: TextStyle(color: muted, fontSize: 12),
      ),
    );
  }

  static ThemeData dark() {
    final base = light();
    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: copper,
        brightness: Brightness.dark,
      ),
    );
  }
}
