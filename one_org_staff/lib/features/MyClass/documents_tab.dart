import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

import 'document_viewer.dart';

/// Document list with upload / open / delete, backed by `/documents`.
class DocumentsTab extends StatefulWidget {
  const DocumentsTab({
    super.key,
    required this.personId,
    required this.isDarkMode,
    required this.loadDocuments,
    required this.createDocument,
    required this.deleteDocument,
    this.pickFile,
  });

  final int personId;
  final bool isDarkMode;
  final Future<List<DocumentEntry>> Function(int personId) loadDocuments;
  final Future<DocumentEntry> Function({
    required int personId,
    required String documentName,
    required String documentType,
    required List<int> bytes,
    required String filename,
  })
  createDocument;
  final Future<void> Function(int documentId) deleteDocument;

  /// Injectable so widget tests can drive uploads without a platform channel.
  final Future<PickedDocument?> Function()? pickFile;

  @override
  State<DocumentsTab> createState() => _DocumentsTabState();
}

/// A chosen file, independent of the picker that produced it.
class PickedDocument {
  const PickedDocument({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

class _DocumentsTabState extends State<DocumentsTab> {
  /// The API caps uploads at 5 MB; refuse locally rather than after the wait.
  static const _maxBytes = 5 * 1024 * 1024;

  late Future<List<DocumentEntry>> _future;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _future = widget.loadDocuments(widget.personId);
  }

  void _reload() {
    setState(() => _future = widget.loadDocuments(widget.personId));
  }

  void _report(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<PickedDocument?> _pick() async {
    final picker = widget.pickFile;
    if (picker != null) {
      return picker();
    }

    // file_picker 11 exposes pickFiles as a static.
    final result = await FilePicker.pickFiles(withData: true);
    final file = result?.files.singleOrNull;
    if (file == null) {
      return null;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      return null;
    }

    return PickedDocument(name: file.name, bytes: bytes);
  }

  Future<void> _upload() async {
    if (_isUploading) {
      return;
    }

    final PickedDocument? picked;
    try {
      picked = await _pick();
    } catch (error) {
      if (mounted) {
        _report('Could not open the file picker: $error');
      }
      return;
    }

    if (picked == null || !mounted) {
      return;
    }

    if (picked.bytes.length > _maxBytes) {
      _report('That file is larger than the 5 MB limit.');
      return;
    }

    final details = await showModalBottomSheet<_DocumentDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DocumentForm(filename: picked!.name),
    );

    if (details == null || !mounted) {
      return;
    }

    setState(() => _isUploading = true);
    try {
      await widget.createDocument(
        personId: widget.personId,
        documentName: details.name,
        documentType: details.type,
        bytes: picked.bytes,
        filename: picked.name,
      );
      if (mounted) {
        _reload();
        _report('Document uploaded.');
      }
    } catch (error) {
      if (mounted) {
        _report(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  /// Shown in place — leaving the app to read a document loses the teacher's
  /// position in the roster.
  Future<void> _open(DocumentEntry document) {
    return showDocumentViewer(context, document: document);
  }

  Future<void> _confirmDelete(DocumentEntry document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document'),
        content: Text('Delete "${document.documentName}"?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.deleteDocument(document.id);
      if (mounted) {
        _reload();
      }
    } catch (error) {
      if (mounted) {
        _report(error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = widget.isDarkMode;
    final mutedColor = appColorsOf(context).mutedText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Documents',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _isUploading ? null : _upload,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_rounded, size: 18),
              label: const Text('Upload'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'PDF, image or document · up to 5MB',
          style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<DocumentEntry>>(
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

            final documents = snapshot.data ?? const <DocumentEntry>[];
            if (documents.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No documents uploaded yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final document in documents) ...[
                  _DocumentCard(
                    document: document,
                    isDarkMode: isDarkMode,
                    onOpen: () => _open(document),
                    onDelete: () => _confirmDelete(document),
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

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.isDarkMode,
    required this.onOpen,
    required this.onDelete,
  });

  final DocumentEntry document;
  final bool isDarkMode;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = appColorsOf(context).mutedText;
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: appColorsOf(context).card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: appColorsOf(context).line),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDarkMode ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.description_outlined, size: 19, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.documentName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (document.documentType.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      document.documentType,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (document.documentUrl != null)
              Icon(Icons.open_in_new_rounded, size: 17, color: mutedColor),
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentDraft {
  const _DocumentDraft({required this.name, required this.type});

  final String name;
  final String type;
}

class _DocumentForm extends StatefulWidget {
  const _DocumentForm({required this.filename});

  final String filename;

  @override
  State<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends State<_DocumentForm> {
  static const _types = ['passport', 'certificate', 'medical', 'other'];

  late final TextEditingController _name;
  String _type = _types.first;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The file name is the obvious default document name.
    _name = TextEditingController(text: widget.filename);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A document name is required.');
      return;
    }
    Navigator.pop(
      context,
      _DocumentDraft(name: _name.text.trim(), type: _type),
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
              'Upload document',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.filename,
              style: theme.textTheme.bodySmall?.copyWith(
                color: appColorsOf(context).mutedText,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Document name',
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Type',
                isDense: true,
              ),
              items: [
                for (final type in _types)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
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
                    child: const Text('Upload'),
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
