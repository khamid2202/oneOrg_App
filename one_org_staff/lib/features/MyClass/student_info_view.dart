import 'package:flutter/material.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/shared/editable_avatar.dart';
import 'package:one_org_staff/shared/underline_tabs.dart';

import 'documents_tab.dart';
import 'guardians_tab.dart';
import 'student_people_sync.dart';

/// Which identification number the form is editing. The web shows one or the
/// other behind a toggle rather than both at once.
enum IdentificationType { passport, birthCertificate }

/// The three sections of the student modal, mirroring the web.
enum StudentTab { profile, guardians, documents }

/// The guardian calls the Guardians tab needs.
class StudentGuardiansApi {
  const StudentGuardiansApi({
    required this.load,
    required this.create,
    required this.update,
    required this.delete,
  });

  final Future<List<GuardianEntry>> Function(int personId) load;
  final Future<GuardianEntry> Function({
    required int personId,
    required String fullName,
    required String relation,
    required String phone,
    String? workAddress,
    String? position,
  })
  create;
  final Future<GuardianEntry> Function({
    required int guardianId,
    String? fullName,
    String? relation,
    String? phone,
    String? workAddress,
    String? position,
  })
  update;
  final Future<void> Function(int guardianId) delete;
}

/// The document calls the Documents tab needs.
class StudentDocumentsApi {
  const StudentDocumentsApi({
    required this.load,
    required this.create,
    required this.delete,
  });

  final Future<List<DocumentEntry>> Function(int personId) load;
  final Future<DocumentEntry> Function({
    required int personId,
    required String documentName,
    required String documentType,
    required List<int> bytes,
    required String filename,
  })
  create;
  final Future<void> Function(int documentId) delete;
}

/// Personal details for one student, editable in place.
///
/// The values come from the `person` object already attached to the roster, so
/// opening a student costs no request; saving PATCHes only what changed.
class StudentInfoView extends StatefulWidget {
  const StudentInfoView({
    super.key,
    required this.student,
    required this.classPair,
    required this.isDarkMode,
    required this.onBack,
    required this.updatePersonDetails,
    required this.uploadPersonPicture,
    required this.removePersonPicture,
    required this.onSaved,
    required this.onPictureChanged,
    required this.guardians,
    required this.documents,
    required this.peopleSync,
    this.initialTab = StudentTab.profile,
  });

  final StudentEntry student;
  final String classPair;
  final bool isDarkMode;
  final VoidCallback onBack;
  final Future<PersonDetails> Function({
    required int personId,
    required Map<String, String> changes,
  })
  updatePersonDetails;
  final Future<String?> Function({
    required int ownerId,
    required List<int> bytes,
    required String filename,
  })
  uploadPersonPicture;
  final Future<String?> Function({required int ownerId}) removePersonPicture;

  /// Lets the roster keep the saved values without a refetch.
  final void Function(StudentEntry student, PersonDetails details) onSaved;
  final void Function(StudentEntry student, String? pictureUrl)
  onPictureChanged;

  /// Everything the Guardians and Documents tabs need, grouped so the widget
  /// signature does not grow another ten callbacks.
  final StudentGuardiansApi guardians;
  final StudentDocumentsApi documents;

  /// Keeps guardians and contacts mirrored when either is saved.
  final StudentPeopleSync peopleSync;

  /// Which tab to land on — Contacts on the roster opens straight to Guardians.
  final StudentTab initialTab;

  @override
  State<StudentInfoView> createState() => _StudentInfoViewState();
}

class _StudentInfoViewState extends State<StudentInfoView> {
  late PersonDetails _saved;

  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _identificationController;

  DateTime? _birthDate;
  String? _gender;
  late IdentificationType _identificationType;

  bool _isSaving = false;
  String? _errorMessage;

  /// Tracked separately from the student so a new photo shows immediately.
  String? _pictureUrl;

  late StudentTab _tab;

  @override
  void initState() {
    super.initState();
    _saved = widget.student.details;
    _pictureUrl = widget.student.pictureUrl;
    _tab = widget.initialTab;
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _identificationController = TextEditingController();
    _resetFieldsFromSaved();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _identificationController.dispose();
    super.dispose();
  }

  void _resetFieldsFromSaved() {
    _birthDate = _saved.birthDate == null
        ? null
        : DateTime.tryParse(_saved.birthDate!);
    _gender = _saved.gender?.trim().toLowerCase();
    _phoneController.text = _saved.phone ?? '';
    _addressController.text = _saved.address ?? '';

    // Show whichever identification the student actually has; passport wins
    // when both are present.
    _identificationType = _saved.passportNumber != null
        ? IdentificationType.passport
        : (_saved.birthCertificateNumber != null
              ? IdentificationType.birthCertificate
              : IdentificationType.passport);
    _identificationController.text = _numberFor(_identificationType) ?? '';
  }

  String? _numberFor(IdentificationType type) {
    return type == IdentificationType.passport
        ? _saved.passportNumber
        : _saved.birthCertificateNumber;
  }

  /// The form's current values as a [PersonDetails].
  ///
  /// Only the selected identification type is written; the other is carried
  /// over untouched so switching the toggle never erases a stored number.
  PersonDetails get _edited {
    final number = _identificationController.text.trim();
    final isPassport = _identificationType == IdentificationType.passport;

    return PersonDetails(
      birthDate: _birthDate == null ? null : _formatIsoDate(_birthDate!),
      gender: _gender,
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      passportNumber: isPassport ? number : _saved.passportNumber,
      birthCertificateNumber: isPassport
          ? _saved.birthCertificateNumber
          : number,
    );
  }

  bool get _isDirty => _edited.diffFrom(_saved).isNotEmpty;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 12),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
      helpText: 'Select birth date',
    );

    if (picked == null || !mounted) {
      return;
    }
    setState(() => _birthDate = picked);
  }

  Future<void> _save() async {
    final changes = _edited.diffFrom(_saved);
    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.updatePersonDetails(
        personId: widget.student.personId,
        changes: changes,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = result;
        _resetFieldsFromSaved();
      });
      widget.onSaved(widget.student, result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student details saved.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancel() {
    setState(() {
      _errorMessage = null;
      _resetFieldsFromSaved();
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = widget.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Back to class',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Student info',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _IdentityCard(
          student: widget.student,
          classPair: widget.classPair,
          isDarkMode: isDarkMode,
          pictureUrl: _pictureUrl,
          uploadPersonPicture: widget.uploadPersonPicture,
          removePersonPicture: widget.removePersonPicture,
          onPictureChanged: (url) {
            setState(() => _pictureUrl = url);
            widget.onPictureChanged(widget.student, url);
          },
          onError: (message) =>
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              ),
        ),
        const SizedBox(height: 16),
        UnderlineTabs<StudentTab>(
          selected: _tab,
          isDarkMode: isDarkMode,
          onSelected: (tab) => setState(() => _tab = tab),
          items: const [
            UnderlineTabItem(
              value: StudentTab.profile,
              label: 'Profile',
              icon: Icons.person_outline_rounded,
            ),
            UnderlineTabItem(
              value: StudentTab.guardians,
              label: 'Guardians',
              icon: Icons.groups_outlined,
            ),
            UnderlineTabItem(
              value: StudentTab.documents,
              label: 'Documents',
              icon: Icons.description_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        switch (_tab) {
          StudentTab.profile => _buildProfileTab(theme, isDarkMode),
          StudentTab.guardians => GuardiansTab(
            personId: widget.student.personId,
            isDarkMode: isDarkMode,
            loadGuardians: widget.guardians.load,
            deleteGuardian: widget.guardians.delete,
            sync: widget.peopleSync,
          ),
          StudentTab.documents => DocumentsTab(
            personId: widget.student.personId,
            isDarkMode: isDarkMode,
            loadDocuments: widget.documents.load,
            createDocument: widget.documents.create,
            deleteDocument: widget.documents.delete,
          ),
        },
      ],
    );
  }

  Widget _buildProfileTab(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      _FormCard(
        title: 'Details',
        icon: Icons.info_outline_rounded,
        headerColor: const Color(0xFF3E88C0),
        isDarkMode: isDarkMode,
        children: [
          _FieldLabel(label: 'Birth Date', isDarkMode: isDarkMode),
          const SizedBox(height: 6),
          _DateField(
            value: _birthDate,
            isDarkMode: isDarkMode,
            onTap: _pickBirthDate,
            onClear: _birthDate == null
                ? null
                : () => setState(() => _birthDate = null),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Gender', isDarkMode: isDarkMode),
          const SizedBox(height: 6),
          _SegmentedToggle(
            options: const ['female', 'male'],
            labels: const ['Female', 'Male'],
            selected: _gender,
            isDarkMode: isDarkMode,
            onSelected: (value) => setState(
              () => _gender = _gender == value ? null : value,
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Phone', isDarkMode: isDarkMode),
          const SizedBox(height: 6),
          _TextField(
            controller: _phoneController,
            hintText: '+998',
            keyboardType: TextInputType.phone,
            isDarkMode: isDarkMode,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Address', isDarkMode: isDarkMode),
          const SizedBox(height: 6),
          _TextField(
            controller: _addressController,
            hintText: 'e.g., Street, City, Country',
            isDarkMode: isDarkMode,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _FormCard(
        title: 'Identification Type',
        icon: Icons.badge_outlined,
        headerColor: const Color(0xFF2F9E77),
        isDarkMode: isDarkMode,
        children: [
          _SegmentedToggle(
            options: const ['passport', 'birth_certificate'],
            labels: const ['Passport', 'Birth Certificate'],
            selected: _identificationType == IdentificationType.passport
                ? 'passport'
                : 'birth_certificate',
            isDarkMode: isDarkMode,
            onSelected: (value) {
              setState(() {
                _identificationType = value == 'passport'
                    ? IdentificationType.passport
                    : IdentificationType.birthCertificate;
                _identificationController.text =
                    _numberFor(_identificationType) ?? '';
              });
            },
          ),
          const SizedBox(height: 16),
          _FieldLabel(
            label: _identificationType == IdentificationType.passport
                ? 'Passport Number'
                : 'Birth Certificate Number',
            isDarkMode: isDarkMode,
          ),
          const SizedBox(height: 6),
          _TextField(
            controller: _identificationController,
            hintText: _identificationType == IdentificationType.passport
                ? 'Passport Number'
                : 'Birth Certificate Number',
            isDarkMode: isDarkMode,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      if (_errorMessage != null) ...[
        const SizedBox(height: 14),
        Text(
          _errorMessage!,
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
              onPressed: _isSaving || !_isDirty ? null : _cancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _isSaving || !_isDirty ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save changes'),
            ),
          ),
        ],
      ),
      ],
    );
  }

  static String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.student,
    required this.classPair,
    required this.isDarkMode,
    required this.pictureUrl,
    required this.uploadPersonPicture,
    required this.removePersonPicture,
    required this.onPictureChanged,
    required this.onError,
  });

  final StudentEntry student;
  final String classPair;
  final bool isDarkMode;
  final String? pictureUrl;
  final Future<String?> Function({
    required int ownerId,
    required List<int> bytes,
    required String filename,
  })
  uploadPersonPicture;
  final Future<String?> Function({required int ownerId}) removePersonPicture;
  final ValueChanged<String?> onPictureChanged;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121A24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF273445)
              : const Color(0xFFD7E1EE),
        ),
      ),
      child: Row(
        children: [
          EditableAvatar(
            fullName: student.fullName,
            imageUrl: pictureUrl,
            // Pictures live on the person record, not the enrollment.
            ownerId: student.personId,
            isDarkMode: isDarkMode,
            radius: 30,
            uploadPicture: uploadPersonPicture,
            removePicture: removePersonPicture,
            onChanged: onPictureChanged,
            onError: onError,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (student.code != null) ...[
                      Text(
                        'Code ${student.code!}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      'Class $classPair',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    required this.icon,
    required this.headerColor,
    required this.isDarkMode,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color headerColor;
  final bool isDarkMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121A24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF273445)
              : const Color(0xFFD7E1EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: headerColor,
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.isDarkMode});

  final String label;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: isDarkMode ? const Color(0xFFC6D3E1) : const Color(0xFF44566B),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hintText,
    required this.isDarkMode,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final bool isDarkMode;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDarkMode
        ? const Color(0xFF3A4B5F)
        : const Color(0xFFD7E1EE);

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF19202A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.6,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.isDarkMode,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? value;
  final bool isDarkMode;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);
    final borderColor = isDarkMode
        ? const Color(0xFF3A4B5F)
        : const Color(0xFFD7E1EE);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF19202A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'dd/mm/yyyy' : _format(value!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: value == null ? mutedColor : null,
                  fontWeight: value == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 18, color: mutedColor),
              ),
            const SizedBox(width: 8),
            Icon(Icons.calendar_today_outlined, size: 18, color: mutedColor),
          ],
        ),
      ),
    );
  }

  static String _format(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.options,
    required this.labels,
    required this.selected,
    required this.isDarkMode,
    required this.onSelected,
  });

  final List<String> options;
  final List<String> labels;
  final String? selected;
  final bool isDarkMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final borderColor = isDarkMode
        ? const Color(0xFF3A4B5F)
        : const Color(0xFFD7E1EE);
    final unselectedForeground = isDarkMode
        ? const Color(0xFFC6D3E1)
        : const Color(0xFF44566B);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++) ...[
            Expanded(
              child: Material(
                color: selected == options[index]
                    ? primary
                    : (isDarkMode ? const Color(0xFF19202A) : Colors.white),
                child: InkWell(
                  onTap: () => onSelected(options[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected == options[index]
                            ? Colors.white
                            : unselectedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (index != options.length - 1)
              SizedBox(width: 1, height: 46, child: ColoredBox(color: borderColor)),
          ],
        ],
      ),
    );
  }
}
