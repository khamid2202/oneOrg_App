import 'package:flutter/material.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

import 'student_people_sync.dart';

/// Guardian list with add / edit / delete, backed by `/guardians`.
class GuardiansTab extends StatefulWidget {
  const GuardiansTab({
    super.key,
    required this.personId,
    required this.isDarkMode,
    required this.loadGuardians,
    required this.deleteGuardian,
    required this.sync,
  });

  final int personId;
  final bool isDarkMode;
  final Future<List<GuardianEntry>> Function(int personId) loadGuardians;
  final Future<void> Function(int guardianId) deleteGuardian;

  /// Saving goes through the sync so the contact list stays in step.
  final StudentPeopleSync sync;

  @override
  State<GuardiansTab> createState() => _GuardiansTabState();
}

class _GuardiansTabState extends State<GuardiansTab> {
  late Future<List<GuardianEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadGuardians(widget.personId);
  }

  void _reload() {
    setState(() => _future = widget.loadGuardians(widget.personId));
  }

  void _report(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  Future<void> _openForm({GuardianEntry? existing}) async {
    final result = await showModalBottomSheet<_GuardianDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GuardianForm(existing: existing),
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await widget.sync.saveGuardian(
        personId: widget.personId,
        guardianId: existing?.id,
        fullName: result.fullName,
        relation: result.relation,
        phone: result.phone,
        workAddress: result.workAddress,
        position: result.position,
        // So changing a number moves the mirrored contact instead of
        // leaving an orphan behind.
        previousPhone: existing?.phone,
      );
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        _report(error);
      }
    }
  }

  Future<void> _confirmDelete(GuardianEntry guardian) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove guardian'),
        content: Text('Remove ${guardian.fullName} from this student?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.deleteGuardian(guardian.id);
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        _report(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = widget.isDarkMode;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Guardians',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<GuardianEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _TabError(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }

            final guardians = snapshot.data ?? const <GuardianEntry>[];
            if (guardians.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No guardians recorded yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final guardian in guardians) ...[
                  _GuardianCard(
                    guardian: guardian,
                    isDarkMode: isDarkMode,
                    onEdit: () => _openForm(existing: guardian),
                    onDelete: () => _confirmDelete(guardian),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GuardianCard extends StatelessWidget {
  const _GuardianCard({
    required this.guardian,
    required this.isDarkMode,
    required this.onEdit,
    required this.onDelete,
  });

  final GuardianEntry guardian;
  final bool isDarkMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2430) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF273445)
              : const Color(0xFFD7E1EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guardian.fullName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guardian.relation,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailLine(icon: Icons.phone_outlined, value: guardian.phone),
          if (guardian.position != null)
            _DetailLine(icon: Icons.work_outline, value: guardian.position!),
          if (guardian.workAddress != null)
            _DetailLine(
              icon: Icons.location_on_outlined,
              value: guardian.workAddress!,
            ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: mutedColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianDraft {
  const _GuardianDraft({
    required this.fullName,
    required this.relation,
    required this.phone,
    this.workAddress,
    this.position,
  });

  final String fullName;
  final String relation;
  final String phone;
  final String? workAddress;
  final String? position;
}

class _GuardianForm extends StatefulWidget {
  const _GuardianForm({this.existing});

  final GuardianEntry? existing;

  @override
  State<_GuardianForm> createState() => _GuardianFormState();
}

class _GuardianFormState extends State<_GuardianForm> {
  late final TextEditingController _fullName;
  late final TextEditingController _relation;
  late final TextEditingController _phone;
  late final TextEditingController _position;
  late final TextEditingController _workAddress;

  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _fullName = TextEditingController(text: existing?.fullName ?? '');
    _relation = TextEditingController(text: existing?.relation ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _position = TextEditingController(text: existing?.position ?? '');
    _workAddress = TextEditingController(text: existing?.workAddress ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _relation.dispose();
    _phone.dispose();
    _position.dispose();
    _workAddress.dispose();
    super.dispose();
  }

  void _submit() {
    // The API rejects these three as empty, so catch it before the round trip.
    if (_fullName.text.trim().isEmpty ||
        _relation.text.trim().isEmpty ||
        _phone.text.trim().isEmpty) {
      setState(() => _error = 'Full name, relation and phone are required.');
      return;
    }

    Navigator.pop(
      context,
      _GuardianDraft(
        fullName: _fullName.text.trim(),
        relation: _relation.text.trim(),
        phone: _phone.text.trim(),
        position: _position.text.trim(),
        workAddress: _workAddress.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add guardian' : 'Edit guardian',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            _Field(controller: _fullName, label: 'Full name'),
            const SizedBox(height: 12),
            _Field(
              controller: _relation,
              label: 'Relation',
              hint: 'e.g. father, mother',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _phone,
              label: 'Phone',
              hint: '+998',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _position,
              label: 'Position (optional)',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _workAddress,
              label: 'Work address (optional)',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
    );
  }
}

class _TabError extends StatelessWidget {
  const _TabError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
