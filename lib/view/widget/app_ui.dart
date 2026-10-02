import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:forui/forui.dart';
import 'package:server_box/core/warm_theme.dart';

/// ForUI and the existing Material routes share colors and system typography.
class AppUiScope extends StatelessWidget {
  const AppUiScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.brightness == Brightness.dark
        ? FTheme.neutral.dark.touch : FTheme.neutral.light.touch;
    final colors = base.colors.copyWith(
      background: theme.scaffoldBackgroundColor, foreground: scheme.onSurface,
      primary: scheme.primary, primaryForeground: scheme.onPrimary,
      secondary: scheme.surfaceContainerHigh, secondaryForeground: scheme.onSurface,
      muted: scheme.surfaceContainerHigh, mutedForeground: scheme.onSurfaceVariant,
      card: scheme.surfaceContainerLow, border: scheme.outlineVariant,
      destructive: scheme.error, destructiveForeground: scheme.onError,
      error: scheme.error, errorForeground: scheme.onError,
    );
    final typeface = FTypeface.inherit(
      colors: colors, touch: true,
      fontFamily: theme.textTheme.bodyMedium?.fontFamily ??
          (theme.platform == TargetPlatform.iOS ? '.SF Pro Text' : 'Roboto'),
      fontFamilyFallback: theme.textTheme.bodyMedium?.fontFamilyFallback,
    );
    final typography = FTypography(display: typeface, body: typeface);
    final style = FStyle.inherit(colors: colors, typography: typography, touch: true).copyWith(
      borderRadius: const FBorderRadius(
        sm: BorderRadius.all(Radius.circular(14)),
        md: BorderRadius.all(Radius.circular(WarmTheme.controlRadius)),
        lg: BorderRadius.all(Radius.circular(WarmTheme.cardRadius)),
      ),
      pagePadding: const EdgeInsetsDelta.value(EdgeInsets.all(WarmTheme.pagePadding)),
    );
    return FTheme(
      data: FThemeData(colors: colors, touch: true,
        typography: typography, style: style),
      motion: FThemeMotion(duration: WarmMotion.of(context, WarmMotion.quick)),
      child: child,
    );
  }
}

/// Finite entrance only: rebuilding with fresh monitoring data does not replay it.
class AppEntrance extends StatelessWidget {
  const AppEntrance({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return child;
    return Animate(effects: const [FadeEffect(duration: Duration(milliseconds: 180))],
      child: child);
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = EdgeInsets.zero,
    this.color, this.radius = WarmTheme.cardRadius});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FCard(
      style: FTheme.of(context).cardStyle.copyWith(
        padding: EdgeInsetsGeometryDelta.value(padding),
        decoration: DecorationDelta.boxDelta(color: color ?? scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45))),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_, style, child) => Padding(padding: style.padding, child: child),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.onPressed, required this.child,
    this.icon, this.secondary = false, this.compact = false});
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool secondary;
  final bool compact;

  @override
  Widget build(BuildContext context) => FButton(
    onPress: onPressed,
    variant: secondary ? FButtonVariant.outline : FButtonVariant.primary,
    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
    prefix: icon == null ? null : Icon(icon, size: 18), child: child,
  );
}

/// FScaffold handles the content layout; the outer Material scaffold retains
/// route, snackbar and keyboard behavior. Insets are applied by the caller.
class AppPageBody extends StatelessWidget {
  const AppPageBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => FScaffold(
    childPad: false, resizeToAvoidBottomInset: false,
    scaffoldStyle: FTheme.of(context).scaffoldStyle.copyWith(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor),
    child: child,
  );
}

/// A brief update fade keeps the actual measurement and its semantics intact.
class AppValueText extends StatelessWidget {
  const AppValueText(this.value, {super.key, this.style, this.textScaler});
  final String value;
  final TextStyle? style;
  final TextScaler? textScaler;
  @override
  Widget build(BuildContext context) {
    final text = Text(value, style: style, textScaler: textScaler);
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return text;
    return Animate(key: ValueKey(value), effects: const [
      FadeEffect(begin: .65, end: 1, duration: Duration(milliseconds: 140)),
    ], child: text);
  }
}

extension AppCardWidget on Widget {
  Widget get appCard => AppCard(child: this);
}
