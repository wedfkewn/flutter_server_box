import 'package:flutter/material.dart';
import 'package:server_box/view/widget/app_ui.dart';

/// A single surface for related server controls; rows keep their own focus.
class ServerGroup extends StatelessWidget {
  const ServerGroup({super.key, this.title, required this.children, this.padding = 12});

  final String? title;
  final List<Widget> children;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(title!, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
