import 'package:choice/choice.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// A shared, centered shell. Routes continue to own dismissal and results.
class AppFloatingDialog extends StatelessWidget {
  const AppFloatingDialog({super.key, this.title, this.content, this.actions,
    this.icon, this.dismissible = true, this.insetPadding,
    this.titlePadding, this.contentPadding, this.actionsPadding});
  final Widget? title, content, icon;
  final List<Widget>? actions;
  final bool dismissible;
  final EdgeInsets? insetPadding;
  final EdgeInsetsGeometry? titlePadding, contentPadding, actionsPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = ModalRoute.of(context);
    final canClose = dismissible && (route?.barrierDismissible ?? true);
    return AlertDialog(
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 420, maxHeight: 560),
      insetPadding: insetPadding ?? const EdgeInsets.all(24),
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      scrollable: true,
      titlePadding: titlePadding ?? const EdgeInsets.fromLTRB(20, 12, 12, 12),
      contentPadding: contentPadding ?? const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsPadding: actionsPadding ?? const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actionsOverflowButtonSpacing: 8,
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      contentTextStyle: theme.textTheme.bodyMedium,
      title: title == null && icon == null && !canClose ? null : Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[IconTheme(data: IconThemeData(
            size: 24, color: theme.colorScheme.primary), child: icon!), const SizedBox(width: 10)],
          if (title != null) Expanded(child: title!) else const Spacer(),
          if (canClose) IconButton(
            key: const ValueKey('floating-dialog-close'), tooltip: libL10n.close,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            icon: const Icon(Icons.close, size: 22)),
        ],
      ),
      content: content,
      actions: actions,
    );
  }
}

/// Choice owns selection semantics; only its presentation changes to rows.
class AppDialogChoices<T> extends StatefulWidget {
  const AppDialogChoices({super.key, required this.items, required this.selected,
    required this.onChanged, this.multi = false, this.clearable = false,
    this.display, this.avatar});
  final List<T> items, selected;
  final ValueChanged<List<T>> onChanged;
  final bool multi, clearable;
  final String? Function(T)? display;
  final Widget? Function(T)? avatar;

  @override
  State<AppDialogChoices<T>> createState() => _AppDialogChoicesState<T>();
}

class _AppDialogChoicesState<T> extends State<AppDialogChoices<T>> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final visible = widget.items.where((item) =>
      (widget.display?.call(item) ?? item.toString()).toLowerCase().contains(_query)).toList();
    return Choice<T>(
      onChanged: widget.onChanged, multiple: widget.multi,
      clearable: widget.clearable, value: widget.selected,
      builder: (state, _) => Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.items.length > 8) ...[
          TextField(key: const ValueKey('dialog-choice-search'),
            decoration: InputDecoration(hintText: libL10n.search,
              prefixIcon: const Icon(Icons.search, size: 20), filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus()),
          const SizedBox(height: 12),
        ],
        if (visible.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(libL10n.empty)),
        for (final item in visible) AppDialogChoiceRow<T>(
          key: ValueKey(item), label: widget.display?.call(item) ?? item.toString(),
          avatar: widget.avatar?.call(item), state: state, value: item),
      ]),
    );
  }
}

class AppDialogChoiceRow<T> extends StatelessWidget {
  const AppDialogChoiceRow({super.key, required this.label, required this.state,
    required this.value, this.avatar});
  final String label;
  final ChoiceController<T> state;
  final T value;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final selected = state.selected(value);
    final colors = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Semantics(
      selected: selected, button: true,
      child: Material(color: selected ? colors.primary.withValues(alpha: .09) : Colors.transparent,
        borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: () => state.onSelected(value)(!selected), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            if (avatar != null) ...[avatar!, const SizedBox(width: 10)],
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500))),
            const SizedBox(width: 10),
            SizedBox(width: 22, child: selected ? Icon(Icons.check, size: 20, color: colors.primary) : null),
          ]),
        )),
      ),
    ));
  }
}
