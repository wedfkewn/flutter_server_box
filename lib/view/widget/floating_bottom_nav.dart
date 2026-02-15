import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class FloatingBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Material(
        color: colorScheme.surfaceContainer,
        elevation: 4,
        shadowColor: colorScheme.shadow,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildItem(context, 0, Icons.dashboard, 'Dashboard'),
              _buildItem(context, 1, Icons.insert_drive_file, 'SFTP'),
              _buildItem(context, 2, FontAwesome.docker_brand, 'Docker'),
              _buildItem(context, 3, Icons.code, 'Snippet'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    IconData icon,
    String tooltip,
  ) {
    final isSelected = currentIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onTap(index),
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
    );
  }
}
