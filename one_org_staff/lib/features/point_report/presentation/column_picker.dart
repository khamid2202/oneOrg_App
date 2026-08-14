import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/point_report/domain/point_report_repository.dart';

/// The three-dots column chooser, ported from the web's column selector.
///
/// Opens a sheet listing every column with a checkbox, a search box for classes
/// with many subjects, a `selected/total` count, and Select all / Clear all.
class ColumnPickerButton extends StatelessWidget {
  const ColumnPickerButton({
    super.key,
    required this.subjects,
    required this.columns,
    required this.onChanged,
  });

  final List<String> subjects;
  final PointReportColumns columns;
  final ValueChanged<PointReportColumns> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return IconButton(
      tooltip: 'Choose columns',
      onPressed: subjects.isEmpty && columns.selected.isEmpty
          ? null
          : () => _open(context),
      icon: const Icon(Icons.more_vert_rounded),
      style: IconButton.styleFrom(
        shape: CircleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        foregroundColor: colors.softText,
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _ColumnPickerSheet(
        subjects: subjects,
        columns: columns,
        onChanged: onChanged,
      ),
    );
  }
}

class _ColumnPickerSheet extends StatefulWidget {
  const _ColumnPickerSheet({
    required this.subjects,
    required this.columns,
    required this.onChanged,
  });

  final List<String> subjects;
  final PointReportColumns columns;
  final ValueChanged<PointReportColumns> onChanged;

  @override
  State<_ColumnPickerSheet> createState() => _ColumnPickerSheetState();
}

class _ColumnPickerSheetState extends State<_ColumnPickerSheet> {
  final _searchController = TextEditingController();

  late PointReportColumns _columns = widget.columns;
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Applied as the user taps rather than on close, so the table updates behind
  /// the sheet — the same immediacy the web's dropdown has.
  void _apply(PointReportColumns next) {
    setState(() => _columns = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    final options = PointReportColumns.optionsFor(widget.subjects);
    final needle = _search.trim().toLowerCase();
    final visible = needle.isEmpty
        ? options
        : options.where((o) => o.label.toLowerCase().contains(needle)).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'Search columns…',
              prefixIcon: Icon(Icons.search_rounded, color: colors.mutedText),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              TextButton(
                onPressed: () => _apply(_columns.selectAll(widget.subjects)),
                child: const Text('Select all'),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.softBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_columns.selected.length}/${options.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.softText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: colors.line),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final option = visible[index];
                return CheckboxListTile(
                  value: _columns.shows(option.key),
                  onChanged: (_) => _apply(_columns.toggle(option.key)),
                  title: Text(option.label),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              },
            ),
          ),

          Divider(color: colors.line),
          Center(
            child: TextButton(
              onPressed: () => _apply(_columns.clearAll()),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Clear all'),
            ),
          ),
        ],
      ),
    );
  }
}
