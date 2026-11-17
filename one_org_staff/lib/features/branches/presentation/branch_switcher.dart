import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../application/branch_controller.dart';

/// One line under the teacher's name, shown only when there is a choice.
class BranchSwitcher extends StatelessWidget {
  const BranchSwitcher({super.key, required this.controller});

  final BranchController controller;

  Future<void> _open(BuildContext context) => pick(context, controller);

  /// The branch list as a bottom sheet; switches when one is picked. Profile
  /// opens the same sheet from its branch row.
  static Future<void> pick(
    BuildContext context,
    BranchController controller,
  ) async {
    final activeId = controller.activeBranchId;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final branch in controller.branches)
              ListTile(
                dense: true,
                title: Text(branch.name),
                selected: branch.id == activeId,
                trailing: branch.id == activeId
                    ? const Icon(Icons.check_rounded, size: 20)
                    : null,
                onTap: () => Navigator.pop(sheetContext, branch.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      controller.switchTo(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final branch = controller.activeBranch;
        if (!controller.canSwitch || branch == null) {
          return const SizedBox.shrink();
        }
        final color = appColorsOf(context).mutedText;
        return InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    branch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 18, color: color),
              ],
            ),
          ),
        );
      },
    );
  }
}
