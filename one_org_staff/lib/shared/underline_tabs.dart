import 'package:flutter/material.dart';

/// One tab in an [UnderlineTabs] bar.
class UnderlineTabItem<T> {
  const UnderlineTabItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// A flat tab bar: icon and label, with the active tab tinted and underlined,
/// sitting on a hairline rule. Matches the web's student modal tabs.
///
/// Generic over the value type so the same bar drives any tabbed section.
class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.isDarkMode,
  });

  final List<UnderlineTabItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool isDarkMode;

  static const _indicatorHeight = 2.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final inactive = isDarkMode
        ? const Color(0xFF8FA3B8)
        : const Color(0xFF64748B);
    final ruleColor = isDarkMode
        ? const Color(0xFF273445)
        : const Color(0xFFE2E8F0);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ruleColor)),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _Tab(
                item: item,
                isSelected: item.value == selected,
                accent: accent,
                inactive: inactive,
                // The rule is drawn by the parent, so the indicator only has
                // to cover it where the tab is active.
                indicatorHeight: _indicatorHeight,
                onTap: () => onSelected(item.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab<T> extends StatelessWidget {
  const _Tab({
    required this.item,
    required this.isSelected,
    required this.accent,
    required this.inactive,
    required this.indicatorHeight,
    required this.onTap,
  });

  final UnderlineTabItem<T> item;
  final bool isSelected;
  final Color accent;
  final Color inactive;
  final double indicatorHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? accent : inactive;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 17, color: foreground),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: indicatorHeight,
            decoration: BoxDecoration(
              color: isSelected ? accent : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
