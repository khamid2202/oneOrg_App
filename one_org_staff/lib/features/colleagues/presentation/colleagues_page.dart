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
    this.bottomInset = 0,
  });

  final Future<List<Colleague>> Function() loadColleagues;

  /// Injected by tests; production goes through `url_launcher`.
  final Future<bool> Function(String uri)? launchDial;

  /// Space the floating nav bar covers at the bottom. The page scrolls itself,
  /// so it has to pad its own list rather than being wrapped in padding.
  final double bottomInset;

  @override
  State<ColleaguesPage> createState() => _ColleaguesPageState();
}

class _ColleaguesPageState extends State<ColleaguesPage> {
  /// Height of the search row, and the offset the list starts scrolled by so
  /// the row sits just off-screen.
  static const _searchHeight = 56.0;

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  /// Starts scrolled past the search row: on Telegram the field lives above the
  /// list and is out of view until you drag down for it, rather than taking up
  /// the top of the screen on every visit.
  final _scrollController = ScrollController(
    initialScrollOffset: _searchHeight,
  );

  late Future<List<Colleague>> _colleaguesFuture;
  String _search = '';
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _colleaguesFuture = widget.loadColleagues();
    // Repaints the placeholder when focus changes.
    _searchFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() => setState(() {});

  @override
  void didUpdateWidget(covariant ColleaguesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadColleagues != widget.loadColleagues) {
      _colleaguesFuture = widget.loadColleagues();
    }
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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

  Future<void> _call(Colleague colleague) =>
      _launch(colleague.dialUri, 'call ${colleague.displayName}');

  Future<void> _message(Colleague colleague) =>
      _launch(colleague.smsUri, 'message ${colleague.displayName}');

  /// Hands [uri] to the OS. [action] completes the sentence "Unable to …".
  Future<void> _launch(String? uri, String action) async {
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
        ..showSnackBar(SnackBar(content: Text('Unable to $action.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return FutureBuilder<List<Colleague>>(
      future: _colleaguesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: _ColleaguesError(
              message: snapshot.error is AuthFailure
                  ? (snapshot.error as AuthFailure).message
                  : 'Unable to load colleagues right now.',
              onRetry: _reload,
            ),
          );
        }

        final all = snapshot.data ?? const <Colleague>[];
        final visible = _visible(all);
        final entries = _entriesFor(visible);

        // The rail overlays the list's right edge, so the rows reserve its
        // width rather than sliding their chevrons underneath it.
        final showsIndex = entries.length > 12;
        final listPadding = EdgeInsets.only(
          left: 20,
          right: showsIndex ? 20 + AlphabetIndex.width : 20,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The title stays put; only the list below it scrolls, so the
            // search row can hide above the list without taking the heading
            // with it.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
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
                  const SizedBox(height: 12),
                ],
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            height: _searchHeight,
                            child: _SearchField(
                              controller: _searchController,
                              focusNode: _searchFocus,
                              showPlaceholder:
                                  _search.isEmpty && !_searchFocus.hasFocus,
                              onChanged: (value) =>
                                  setState(() => _search = value),
                              onClear: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                            ),
                          ),
                        ),
                      ),

                      if (entries.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _ColleaguesEmpty(
                              hasSearch: _search.trim().isNotEmpty,
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return Padding(
                              padding: listPadding,
                              child: entry.colleague == null
                                  ? _GroupLetter(letter: entry.letter!)
                                  : _ColleagueRow(
                                      colleague: entry.colleague!,
                                      expanded:
                                          _expandedId == entry.colleague!.id,
                                      onToggle: () => setState(() {
                                        _expandedId =
                                            _expandedId == entry.colleague!.id
                                            ? null
                                            : entry.colleague!.id;
                                      }),
                                      onCall: () => _call(entry.colleague!),
                                      onMessage: () =>
                                          _message(entry.colleague!),
                                    ),
                            );
                          },
                        ),

                      SliverToBoxAdapter(
                        child: SizedBox(height: widget.bottomInset + 24),
                      ),
                    ],
                  ),

                  // The A–Z rail sits over the list's right edge; dragging it
                  // jumps to a letter without flicking through the whole
                  // directory.
                  if (showsIndex)
                    Positioned(
                      top: 0,
                      bottom: widget.bottomInset,
                      right: 0,
                      child: AlphabetIndex(
                        letters: _lettersIn(entries),
                        onLetter: (letter) => _jumpToLetter(entries, letter),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The letters that actually have people under them, in list order.
  List<String> _lettersIn(List<_ListEntry> entries) => [
    for (final entry in entries)
      if (entry.letter != null) entry.letter!,
  ];

  /// Scrolls so [letter]'s heading sits at the top of the list.
  ///
  /// Offsets are computed from the fixed row and heading heights rather than
  /// measured, which is what lets the jump happen for a letter whose rows have
  /// not been built yet — the whole point of an index on a long list.
  void _jumpToLetter(List<_ListEntry> entries, String letter) {
    var offset = _searchHeight;

    for (final entry in entries) {
      if (entry.letter == letter) {
        break;
      }
      offset += entry.letter != null
          ? _GroupLetter.height
          : _ColleagueRow.rowHeight +
                _ColleagueRow.rowGap +
                (entry.colleague!.id == _expandedId
                    ? _ColleagueRow.panelHeight
                    : 0);
    }

    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.jumpTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  /// Flattens the grouped list into letter headings and rows, so the sliver can
  /// build only what is on screen instead of every row up front.
  List<_ListEntry> _entriesFor(List<Colleague> colleagues) {
    final entries = <_ListEntry>[];
    String? currentLetter;

    for (final colleague in colleagues) {
      if (colleague.sortLetter != currentLetter) {
        currentLetter = colleague.sortLetter;
        entries.add(_ListEntry.letter(currentLetter));
      }
      entries.add(_ListEntry.colleague(colleague));
    }

    return entries;
  }
}

/// One row of the flattened list: either a letter heading or a colleague.
class _ListEntry {
  const _ListEntry.letter(this.letter) : colleague = null;
  const _ListEntry.colleague(this.colleague) : letter = null;

  final String? letter;
  final Colleague? colleague;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.showPlaceholder,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// True while the field is empty and unfocused — the only time the centred
  /// icon+label stands in for the caret.
  final bool showPlaceholder;

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            // No hintText: the placeholder is an icon and a word together, and
            // a hint string cannot carry the icon. It is drawn on top instead.
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Clear search',
                  ),
          ),
        ),

        // Sits above the field but passes taps through, so tapping the
        // placeholder focuses the input underneath it.
        if (showPlaceholder)
          IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 20, color: colors.mutedText),
                const SizedBox(width: 6),
                Text(
                  'Search',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: colors.mutedText),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GroupLetter extends StatelessWidget {
  const _GroupLetter({required this.letter});

  /// Fixed so the A–Z index can compute a letter's scroll offset.
  static const height = 24.0;

  final String letter;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
        child: Text(
          letter,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.softText,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
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
    required this.onMessage,
  });

  final Colleague colleague;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  /// Collapsed row height and the height the panel adds — the A–Z index needs
  /// these to work out where a letter starts, so they are fixed rather than
  /// left to intrinsic sizing.
  static const rowHeight = 52.0;
  static const rowGap = 2.0;
  static const panelHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final phone = colleague.phoneNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: rowGap),
      decoration: BoxDecoration(
        color: expanded ? colors.card : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: SizedBox(
              height: rowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _ColleagueAvatar(colleague: colleague),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        colleague.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (expanded)
            Container(
              height: panelHeight,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: colors.softBg,
                border: Border(top: BorderSide(color: colors.line)),
              ),
              child: phone == null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No phone number',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.mutedText,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            phone,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Icons alone: the two glyphs say call and message
                        // without spending a third of the row on labels.
                        _ActionButton(
                          icon: Icons.sms_rounded,
                          tooltip: 'Message ${colleague.displayName}',
                          onPressed: onMessage,
                        ),
                        const SizedBox(width: 6),
                        _ActionButton(
                          icon: Icons.call_rounded,
                          tooltip: 'Call ${colleague.displayName}',
                          onPressed: onCall,
                          filled: true,
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// A compact circular action in the expanded row.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? theme.colorScheme.primary : colors.card,
        shape: CircleBorder(
          side: filled ? BorderSide.none : BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 17,
              color: filled ? Colors.white : colors.softText,
            ),
          ),
        ),
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
      radius: 17,
      backgroundColor: hasPicture ? colors.softBg : colors.avatarPlaceholder,
      backgroundImage: hasPicture ? NetworkImage(pictureUrl) : null,
      // A broken or offline photo must not take the row down with it.
      onBackgroundImageError: hasPicture ? (_, _) {} : null,
      child: hasPicture
          ? null
          : Text(
              colleague.initials,
              style: TextStyle(
                color: colors.accent.solid,
                fontWeight: FontWeight.w800,
                fontSize: 12,
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

/// The A–Z rail down the right edge of a long list.
///
/// A drag reports whichever letter is under the finger, so running down the
/// rail scrubs through the directory the way the system contacts app does.
class AlphabetIndex extends StatefulWidget {
  const AlphabetIndex({
    super.key,
    required this.letters,
    required this.onLetter,
  });

  /// Width the list reserves for the rail.
  static const width = 22.0;

  final List<String> letters;
  final ValueChanged<String> onLetter;

  @override
  State<AlphabetIndex> createState() => AlphabetIndexState();
}

class AlphabetIndexState extends State<AlphabetIndex> {
  String? _active;

  void _report(Offset localPosition, double height) {
    if (widget.letters.isEmpty || height <= 0) {
      return;
    }

    final slot = height / widget.letters.length;
    final index = (localPosition.dy ~/ slot).clamp(
      0,
      widget.letters.length - 1,
    );
    final letter = widget.letters[index];

    if (letter == _active) {
      return;
    }

    setState(() => _active = letter);
    widget.onLetter(letter);
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (d) => _report(d.localPosition, height),
          onVerticalDragUpdate: (d) => _report(d.localPosition, height),
          onVerticalDragEnd: (_) => setState(() => _active = null),
          onTapDown: (d) => _report(d.localPosition, height),
          onTapUp: (_) => setState(() => _active = null),
          child: SizedBox(
            width: AlphabetIndex.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final letter in widget.letters)
                    Expanded(
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: letter == _active
                                ? Theme.of(context).colorScheme.primary
                                : colors.mutedText,
                          ),
                        ),
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
