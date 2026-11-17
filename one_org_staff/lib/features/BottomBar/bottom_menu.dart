import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';

class BottomMenuItem {
  const BottomMenuItem({
    required this.label,
    required this.icon,
    this.color,
    this.showDot = false,
  });

  final String label;
  final IconData icon;

  /// The app's own colour while unselected. Null follows the text colour.
  final Color? color;

  /// A red dot on the icon: something is waiting behind this tab.
  final bool showDot;
}

/// The phone bar, docked like the web's. [selectedIndex] is -1 on a page that
/// has no button here.
class BottomMenu extends StatelessWidget {
  const BottomMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BottomMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  for (var index = 0; index < items.length; index++)
                    Expanded(
                      child: _BottomMenuButton(
                        item: items[index],
                        isSelected: index == selectedIndex,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomMenuButton extends StatelessWidget {
  const _BottomMenuButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final BottomMenuItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final accent = colors.accent;
    final idle = item.color ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? accent.solid : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 22,
                    color: isSelected ? Colors.white : idle,
                  ),
                ),
                if (item.showDot)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? accent.ring : colors.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
