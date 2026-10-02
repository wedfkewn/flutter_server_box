import 'package:flutter/material.dart';

/// Use a compact Flutter toolbar rather than the Cupertino overflow surface.
Widget buildAppTextEditMenu(BuildContext context, EditableTextState state) {
  final items = state.contextMenuButtonItems.where((item) => {
    ContextMenuButtonType.cut, ContextMenuButtonType.copy,
    ContextMenuButtonType.paste, ContextMenuButtonType.selectAll,
  }.contains(item.type)).toList();
  if (items.isEmpty) return const SizedBox.shrink();
  final anchors = state.contextMenuAnchors;
  return TextSelectionToolbar(
    anchorAbove: anchors.primaryAnchor,
    anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
    children: [for (final item in items) TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: item.onPressed,
      child: Text(AdaptiveTextSelectionToolbar.getButtonLabel(context, item)),
    )],
  );
}
