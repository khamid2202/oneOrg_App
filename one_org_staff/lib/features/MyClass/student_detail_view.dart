import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

import 'circle_action_button.dart';
import 'contact_form.dart';
import 'my_class_status_layouts.dart';

class StudentDetailView extends StatefulWidget {
  const StudentDetailView({
    super.key,
    required this.student,
    required this.classPair,
    required this.isDarkMode,
    required this.loadContacts,
    required this.createContact,
    required this.updateContact,
    required this.deleteContact,
    required this.onBack,
  });

  final StudentEntry student;
  final String classPair;
  final bool isDarkMode;
  final Future<List<ContactEntry>> Function(int studentId) loadContacts;
  final Future<ContactEntry> Function({
    required int studentId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
  }) createContact;
  final Future<ContactEntry> Function({
    required int contactId,
    String? fullName,
    String? relationship,
    String? phoneNumber,
  }) updateContact;
  final Future<void> Function(int contactId) deleteContact;
  final VoidCallback onBack;

  @override
  State<StudentDetailView> createState() => _StudentDetailViewState();
}

class _StudentDetailViewState extends State<StudentDetailView> {
  List<ContactEntry>? _contacts;
  bool _isLoading = true;
  String? _error;
  bool _showAddForm = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contacts = await widget.loadContacts(widget.student.id);
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleCreate(String fullName, String relationship, String phone) async {
    try {
      await widget.createContact(
        studentId: widget.student.id,
        fullName: fullName,
        relationship: relationship,
        phoneNumber: phone,
      );
      _showAddForm = false;
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleUpdate(int contactId, String fullName, String relationship, String phone) async {
    try {
      await widget.updateContact(
        contactId: contactId,
        fullName: fullName,
        relationship: relationship,
        phoneNumber: phone,
      );
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleDelete(int contactId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: const Text('Are you sure you want to remove this contact?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.deleteContact(contactId);
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _callPhone(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final mutedColor = isDark ? const Color(0xFF9DB0C1) : const Color(0xFF5C738B);
    final cardBg = isDark ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB);
    final borderColor = isDark ? const Color(0xFF273445) : const Color(0xFFD7E1EE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF223042) : const Color(0xFFE8F0FA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.student.fullName,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.classPair,
                      style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Content
        if (_isLoading)
          const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          ErrorLayout(message: _error!, onRetry: _loadContacts)
        else ...[
          // Existing contacts
          if (_contacts != null && _contacts!.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _contacts!.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final contact = _contacts![index];
                return ContactCard(
                  contact: contact,
                  isDarkMode: isDark,
                  onCall: () => _callPhone(contact.phoneNumber),
                  onEdit: (fullName, relationship, phone) =>
                      _handleUpdate(contact.id, fullName, relationship, phone),
                  onDelete: () => _handleDelete(contact.id),
                );
              },
            ),

          if (_contacts != null && _contacts!.isEmpty && !_showAddForm)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.contacts_outlined, size: 48, color: mutedColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'No contacts saved yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),

          // Add contact form
          if (_showAddForm) ...[
            const SizedBox(height: 16),
            AddContactForm(
              isDarkMode: isDark,
              onSave: _handleCreate,
              onCancel: () => setState(() => _showAddForm = false),
            ),
          ],

          // + Add button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showAddForm = !_showAddForm),
              icon: Icon(_showAddForm ? Icons.close_rounded : Icons.add_rounded),
              label: Text(_showAddForm ? 'Close' : 'Add'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: borderColor),
                foregroundColor: isDark ? const Color(0xFF64AFFF) : const Color(0xFF4A7FC1),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

const relationshipColors = <String, Color>{
  'mother': Color(0xFF4ADE80),
  'father': Color(0xFF60A5FA),
  'brother': Color(0xFFFBBF24),
  'sister': Color(0xFFF472B6),
  'grandfather': Color(0xFF818CF8),
  'grandmother': Color(0xFFC084FC),
  'uncle': Color(0xFF2DD4BF),
  'aunt': Color(0xFFFB923C),
  'cousin': Color(0xFF67E8F9),
  'self': Color(0xFFA3E635),
  'other': Color(0xFF94A3B8),
};

class ContactCard extends StatefulWidget {
  const ContactCard({
    super.key,
    required this.contact,
    required this.isDarkMode,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  final ContactEntry contact;
  final bool isDarkMode;
  final VoidCallback onCall;
  final void Function(String fullName, String relationship, String phone) onEdit;
  final VoidCallback onDelete;

  @override
  State<ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> {
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late String _relationship;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.contact.fullName);
    _phoneCtrl = TextEditingController(text: widget.contact.phoneNumber);
    _relationship = widget.contact.relationship;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _isEditing = true;
      _nameCtrl.text = widget.contact.fullName;
      _phoneCtrl.text = widget.contact.phoneNumber;
      _relationship = widget.contact.relationship;
    });
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    widget.onEdit(_nameCtrl.text.trim(), _relationship, _phoneCtrl.text.trim());
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB);
    final borderColor = isDark ? const Color(0xFF273445) : const Color(0xFFD7E1EE);
    final badgeColor = relationshipColors[widget.contact.relationship] ?? const Color(0xFF94A3B8);

    if (_isEditing) {
      return EditContactForm(
        isDarkMode: isDark,
        nameController: _nameCtrl,
        phoneController: _phoneCtrl,
        relationship: _relationship,
        isSaving: _isSaving,
        onRelationshipChanged: (v) => setState(() => _relationship = v),
        onSave: _save,
        onCancel: () => setState(() => _isEditing = false),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.contact.relationshipLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              CircleActionButton(
                icon: Icons.phone_rounded,
                color: const Color(0xFF4ADE80),
                isDarkMode: isDark,
                onTap: widget.onCall,
              ),
              const SizedBox(width: 8),
              CircleActionButton(
                icon: Icons.edit_rounded,
                color: const Color(0xFF60A5FA),
                isDarkMode: isDark,
                onTap: _startEdit,
              ),
              const SizedBox(width: 8),
              CircleActionButton(
                icon: Icons.close_rounded,
                color: const Color(0xFFFB7185),
                isDarkMode: isDark,
                onTap: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.contact.fullName,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.contact.phoneNumber,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? const Color(0xFFB7C3D1) : const Color(0xFF4A5F73),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
