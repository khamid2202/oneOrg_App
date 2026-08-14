import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';

/// Staff directory — a port of the web app's Colleagues page.
///
/// Names only, grouped A–Z. Tapping a row expands it in place to reveal the
/// phone number and a call button; there is no detail screen, so finding a
/// number is one tap and never leaves the list. One row is open at a time.
class ColleaguesPage extends StatefulWidget {
  const ColleaguesPage({
    super.key,
    required this.loadColleagues,
    this.launchDial,
  });

  final Future<List<Colleague>> Function() loadColleagues;

  /// Injected by tests; production goes through `url_launcher`.
  final Future<bool> Function(String uri)? launchDial;

  @override
  State<ColleaguesPage> createState() => _ColleaguesPageState();
}

class _ColleaguesPageState extends State<ColleaguesPage> {
  final _searchController = TextEditingController();

  late Future<List<Colleague>> _colleaguesFuture;
  String _search = '';
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _colleaguesFuture = widget.loadColleagues();
  }

  @override
  void didUpdateWidget(covariant ColleaguesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadColleagues != widget.loadColleagues) {
      _colleaguesFuture = widget.loadColleagues();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _colleaguesFuture = widget.loadColleagues();
    });
  }

  /// Active staff only, matching the search, sorted by name — the same
  /// pipeline as the web's `useColleaguesData`.
  List<Colleague> _visible(List<Colleague> all) {
    final filtered = all
        .where((c) => c.isActive && c.matches(_search))
        .toList();
    filtered.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return filtered;
  }

  Future<void> _call(Colleague colleague) async {
    final uri = colleague.dialUri;
    if (uri == null) {
      return;
    }

    final launcher =
        widget.launchDial ??
        (String target) =>
            launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);

    final launched = await launcher(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Unable to call ${colleague.displayName}.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: FutureBuilder<List<Colleague>>(
        future: _colleaguesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _ColleaguesError(
              message: snapshot.error is AuthFailure
                  ? (snapshot.error as AuthFailure).message
                  : 'Unable to load colleagues right now.',
              onRetry: _reload,
            );
          }

          final all = snapshot.data ?? const <Colleague>[];
          final visible = _visible(all);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Colleagues',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                visible.length == 1
                    ? '1 active colleague'
                    : '${visible.length} active colleagues',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(height: 18),

              _SearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
              ),
              const SizedBox(height: 18),

              if (visible.isEmpty)
                _ColleaguesEmpty(hasSearch: _search.trim().isNotEmpty)
              else
                ..._buildGroups(visible),
            ],
          );
        },
      ),
    );
  }

  /// Rows grouped under their first letter, as on the web.
  List<Widget> _buildGroups(List<Colleague> colleagues) {
    final widgets = <Widget>[];
    String? currentLetter;

    for (final colleague in colleagues) {
      if (colleague.sortLetter != currentLetter) {
        currentLetter = colleague.sortLetter;
        widgets.add(_GroupLetter(letter: currentLetter));
      }

      widgets.add(
        _ColleagueRow(
          colleague: colleague,
          expanded: _expandedId == colleague.id,
          onToggle: () => setState(() {
            _expandedId = _expandedId == colleague.id ? null : colleague.id;
          }),
          onCall: () => _call(colleague),
        ),
      );
    }

    return widgets;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by name, phone, or email…',
        prefixIcon: Icon(Icons.search_rounded, color: colors.mutedText),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear search',
              ),
      ),
    );
  }
}

class _GroupLetter extends StatelessWidget {
  const _GroupLetter({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.softText,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ColleagueRow extends StatelessWidget {
  const _ColleagueRow({
    required this.colleague,
    required this.expanded,
    required this.onToggle,
    required this.onCall,
  });

  final Colleague colleague;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final phone = colleague.phoneNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: expanded ? colors.ring : colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _ColleagueAvatar(colleague: colleague),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      colleague.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: colors.softBg,
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: phone == null
                  ? Text(
                      'No phone number',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.mutedText,
                      ),
                    )
                  : Row(
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 18,
                          color: colors.softText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            phone,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: onCall,
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: const Text('Call'),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _ColleagueAvatar extends StatelessWidget {
  const _ColleagueAvatar({required this.colleague});

  final Colleague colleague;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final pictureUrl = colleague.pictureUrl;
    final hasPicture = pictureUrl != null && pictureUrl.isNotEmpty;

    return CircleAvatar(
      radius: 22,
      backgroundColor: colors.softBg,
      backgroundImage: hasPicture ? NetworkImage(pictureUrl) : null,
      // A broken or offline photo must not take the row down with it.
      onBackgroundImageError: hasPicture ? (_, _) {} : null,
      child: hasPicture
          ? null
          : Text(
              colleague.initials,
              style: TextStyle(
                color: colors.softText,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _ColleaguesEmpty extends StatelessWidget {
  const _ColleaguesEmpty({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.groups_rounded, size: 48, color: colors.mutedText),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? 'No colleagues found matching your search.'
                  : 'No colleagues found.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ColleaguesError extends StatelessWidget {
  const _ColleaguesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.mutedText),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
