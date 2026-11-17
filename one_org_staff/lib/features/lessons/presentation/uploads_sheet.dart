import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/lessons_outbox.dart';
import '../domain/lessons_repository.dart';

const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);

/// Shows only while saves are still on this phone or the server refused one.
class UploadsPill extends StatelessWidget {
  const UploadsPill({super.key, required this.outbox});

  final LessonsOutbox outbox;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: outbox,
      builder: (context, _) {
        final total = outbox.entries.length;
        if (total == 0) return const SizedBox.shrink();
        final waiting = outbox.waitingCount;
        final refused = total - waiting;
        return Material(
          color: refused > 0 ? _red : _amber,
          shape: const StadiumBorder(),
          elevation: 3,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showUploadsSheet(context, outbox),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    refused > 0
                        ? Icons.warning_amber_rounded
                        : Icons.cloud_upload_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${refused > 0 ? refused : waiting}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showUploadsSheet(BuildContext context, LessonsOutbox outbox) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UploadsSheet(outbox: outbox),
  );
}

class _UploadsSheet extends StatelessWidget {
  const _UploadsSheet({required this.outbox});

  final LessonsOutbox outbox;

  String _kindLabel(AppLocalizations l, UploadKind kind) => switch (kind) {
    UploadKind.attendance => l.attendance,
    UploadKind.grades => l.scores,
    UploadKind.behavior => l.behavior,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final time = MaterialLocalizations.of(context);

    return ListenableBuilder(
      listenable: outbox,
      builder: (context, _) {
        final entries = outbox.entries;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.uploads,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (outbox.waitingCount > 0)
                        TextButton.icon(
                          onPressed: outbox.retryAll,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(l.tryNow),
                        ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.line),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final refused = !entry.isWaiting;
                      final detail = refused
                          ? l.notAccepted(entry.error ?? '')
                          : entry.attempts > 0
                          ? l.waitingForConnection(entry.attempts)
                          : null;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: [
                            Icon(
                              refused
                                  ? Icons.warning_amber_rounded
                                  : Icons.cloud_upload_outlined,
                              size: 18,
                              color: refused ? _red : _amber,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.label} · ${_kindLabel(l, entry.kind)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (detail != null)
                                    Text(
                                      detail,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: refused
                                            ? _red
                                            : colors.mutedText,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(
                                time.formatTimeOfDay(
                                  TimeOfDay.fromDateTime(entry.createdAt),
                                  alwaysUse24HourFormat: true,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.mutedText,
                                ),
                              ),
                            ),
                            if (refused)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: l.discard,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                  color: _red,
                                ),
                                onPressed: () => outbox.discard(entry.id),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
