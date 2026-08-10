import 'package:flutter/material.dart';

const relationships = <String, String>{
  'mother': 'Mother',
  'father': 'Father',
  'brother': 'Brother',
  'sister': 'Sister',
  'grandfather': 'Grandfather',
  'grandmother': 'Grandmother',
  'uncle': 'Uncle',
  'aunt': 'Aunt',
  'cousin': 'Cousin',
  'self': 'Self',
  'other': 'Other',
};

class AddContactForm extends StatefulWidget {
  const AddContactForm({
    super.key,
    required this.isDarkMode,
    required this.onSave,
    required this.onCancel,
  });

  final bool isDarkMode;
  final void Function(String fullName, String relationship, String phone) onSave;
  final VoidCallback onCancel;

  @override
  State<AddContactForm> createState() => _AddContactFormState();
}

class _AddContactFormState extends State<AddContactForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+998');
  String _relationship = 'other';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    widget.onSave(_nameCtrl.text.trim(), _relationship, _phoneCtrl.text.trim());
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB);
    final borderColor = isDark ? const Color(0xFF273445) : const Color(0xFFD7E1EE);

    return ContactFormCard(
      isDarkMode: isDark,
      cardBg: cardBg,
      borderColor: borderColor,
      nameController: _nameCtrl,
      phoneController: _phoneCtrl,
      relationship: _relationship,
      isSaving: _isSaving,
      onRelationshipChanged: (v) => setState(() => _relationship = v),
      onSave: _submit,
      onCancel: widget.onCancel,
    );
  }
}

class EditContactForm extends StatelessWidget {
  const EditContactForm({
    super.key,
    required this.isDarkMode,
    required this.nameController,
    required this.phoneController,
    required this.relationship,
    required this.isSaving,
    required this.onRelationshipChanged,
    required this.onSave,
    required this.onCancel,
  });

  final bool isDarkMode;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String relationship;
  final bool isSaving;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDarkMode ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB);
    final borderColor = isDarkMode ? const Color(0xFF273445) : const Color(0xFFD7E1EE);

    return ContactFormCard(
      isDarkMode: isDarkMode,
      cardBg: cardBg,
      borderColor: borderColor,
      nameController: nameController,
      phoneController: phoneController,
      relationship: relationship,
      isSaving: isSaving,
      onRelationshipChanged: onRelationshipChanged,
      onSave: onSave,
      onCancel: onCancel,
    );
  }
}

class ContactFormCard extends StatelessWidget {
  const ContactFormCard({
    super.key,
    required this.isDarkMode,
    required this.cardBg,
    required this.borderColor,
    required this.nameController,
    required this.phoneController,
    required this.relationship,
    required this.isSaving,
    required this.onRelationshipChanged,
    required this.onSave,
    required this.onCancel,
  });

  final bool isDarkMode;
  final Color cardBg;
  final Color borderColor;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String relationship;
  final bool isSaving;
  final ValueChanged<String> onRelationshipChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
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
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: relationship,
                  decoration: InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  isExpanded: true,
                  items: relationships.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onRelationshipChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: isSaving ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: borderColor),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: isSaving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6AE8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
