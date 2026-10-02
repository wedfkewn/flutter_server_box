import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/view/widget/app_ui.dart';

bool warmSettingsPhone(BuildContext context) => MediaQuery.sizeOf(context).width < 600;

String warmSettingsText(BuildContext context, String zh, String en) =>
  Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

/// A shared surface for settings, retaining each row's original bindings.
class WarmSettingsSurface extends StatelessWidget {
  const WarmSettingsSurface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!warmSettingsPhone(context)) return child;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Theme(data: theme.copyWith(
      listTileTheme: theme.listTileTheme.copyWith(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        minLeadingWidth: 24, horizontalTitleGap: 12,
        iconColor: scheme.primary,
        titleTextStyle: theme.textTheme.titleSmall?.copyWith(
          fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
        subtitleTextStyle: theme.textTheme.bodySmall?.copyWith(
          fontSize: 12, height: 1.45, color: scheme.onSurfaceVariant)),
      dividerTheme: theme.dividerTheme.copyWith(color: scheme.outlineVariant),
      expansionTileTheme: theme.expansionTileTheme.copyWith(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        iconColor: scheme.primary, collapsedIconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface, collapsedTextColor: scheme.onSurface,
        shape: const Border(), collapsedShape: const Border()),
    ), child: child);
  }
}

/// Related controls share one card with quiet separators instead of one card
/// per row. On a wide screen the previous card layout stays available.
class WarmSettingsGroup extends StatelessWidget {
  const WarmSettingsGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    if (!warmSettingsPhone(context)) {
      return Column(children: children.map((row) => CardX(child: row)).toList());
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(5, 0, 5, 8), child: Text(title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700))),
        AppCard(
          child: Column(children: [for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14), children[i],
          ]])),
      ]));
  }
}

/// A compact explanation at the top of a settings page, using real copy.
class WarmSettingsIntro extends StatelessWidget {
  const WarmSettingsIntro({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: scheme.onPrimaryContainer, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant, height: 1.5))),
      ]));
  }
}

class WarmSettingValue extends StatelessWidget {
  const WarmSettingValue(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: warmSettingsPhone(context) ? 98 : 220),
    child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)));
}
