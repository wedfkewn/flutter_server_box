import 'package:flutter/material.dart';
import 'package:server_box/view/page/ssh/float.dart';

/// The terminal window floating above the current tab.
class FloatingPanels extends StatelessWidget {
  const FloatingPanels({super.key, required this.area});
  final Size area;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [TerminalFloatingShell(area: area)],
  );
}
