import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../MyLessons/lesson_points_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../landing/domain/app_items.dart';
import '../../landing/presentation/teacher_home.dart';
import '../domain/app_search.dart';

const _maxPageResults = 24;

/// Builds the profile a person result opens: the same one My Class shows.
typedef PersonProfileBuilder =
    Widget Function(
      BuildContext context,
      StudentEntry student,
      String classPair,
      VoidCallback onBack,
    );

/// One box over every screen of the app and everyone on record — the phone
/// version of the web's ⌘K search. Screens are matched on the phone and show
/// at once; people come from the server a moment later.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.access,
    required this.onOpenItem,
    required this.onOpenPlace,
    this.repository,
    this.canSearchPeople = false,
    this.hasNotifications = false,
    this.profileBuilder,
    this.debounce = const Duration(milliseconds: 350),
  });

  final AppAccess access;
  final void Function(AppItem item) onOpenItem;
  final void Function(SearchPlace place) onOpenPlace;
  final SearchRepository? repository;

  /// The web's rule: anyone holding a `persons.*` or `students.*` key.
  final bool canSearchPeople;
  final bool hasNotifications;
  final PersonProfileBuilder? profileBuilder;
  final Duration debounce;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  Timer? _timer;

  /// Only the newest request may write to the list.
  int _request = 0;
  String _term = '';
  List<PersonHit> _people = const [];
  int _total = 0;
  int _page = 1;
  int _pages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _locked = false;
  String? _error;
  int? _opening;

  bool get _peopleOn =>
      widget.canSearchPeople && widget.repository != null && !_locked;

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _timer?.cancel();
    final term = value.trim();
    if (!_peopleOn || term.length < minPeopleQuery) {
      _request++;
      setState(() {
        _term = '';
        _people = const [];
        _total = 0;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    _timer = Timer(widget.debounce, () => _search(term, 1));
  }

  Future<void> _search(String term, int page) async {
    final request = ++_request;
    setState(() {
      if (page == 1) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final result = await widget.repository!.searchPeople(term, page: page);
      if (!mounted || request != _request) return;
      setState(() {
        _term = term;
        _people = page == 1 ? result.people : [..._people, ...result.people];
        _total = result.total;
        _page = page;
        _pages = result.pages;
      });
    } on SearchLocked {
      if (!mounted || request != _request) return;
      setState(() {
        _locked = true;
        _people = const [];
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _people = page == 1 ? const [] : _people;
        _error = error is AuthFailure ? error.message : null;
        _error ??= AppLocalizations.of(context).searchFailed;
      });
    } finally {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  bool _allowed(SearchEntry entry) => switch (entry.place) {
    SearchPlace.notifications => widget.hasNotifications,
    SearchPlace() => true,
    null => widget.access.allows(entry.item!),
  };

  String _title(AppLocalizations l, SearchEntry entry) => switch (entry.place) {
    SearchPlace.home => l.home,
    SearchPlace.profile => l.profile,
    SearchPlace.notifications => l.notifications,
    null => appLabel(l, entry.item!),
  };

  IconData _icon(SearchEntry entry) => switch (entry.place) {
    SearchPlace.home => Icons.home_rounded,
    SearchPlace.profile => Icons.person_rounded,
    SearchPlace.notifications => Icons.notifications_rounded,
    null => appIcon(entry.item!),
  };

  /// Names in every language, the one on screen first.
  List<String> _titles(AppLocalizations shown, SearchEntry entry) => {
    _title(shown, entry),
    for (final code in const ['en', 'uz', 'ru'])
      _title(lookupAppLocalizations(Locale(code)), entry),
  }.toList();

  List<SearchEntry> _matches(AppLocalizations l, List<String> tokens) {
    final allowed = searchCatalog.where(_allowed);
    if (tokens.isEmpty) return allowed.toList();
    final scored =
        [
            for (final entry in allowed)
              (
                entry,
                scoreSearchEntry(
                  _titles(l, entry),
                  entry.keywords,
                  tokens,
                  _query.text,
                ),
              ),
          ].where((pair) => pair.$2 > 0).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(_maxPageResults).map((pair) => pair.$1).toList();
  }

  void _openEntry(SearchEntry entry) {
    Navigator.of(context).pop();
    if (entry.item != null) {
      widget.onOpenItem(entry.item!);
    } else {
      widget.onOpenPlace(entry.place!);
    }
  }

  Future<void> _openPerson(PersonHit person) async {
    final builder = widget.profileBuilder;
    if (builder == null || _opening != null) return;
    setState(() => _opening = person.id);
    List<Map<String, dynamic>> enrollments = const [];
    try {
      enrollments = await widget.repository!.enrollmentsOf(person.id);
    } catch (_) {
      // Without an enrollment the profile still shows the person.
    }
    if (!mounted) return;
    setState(() => _opening = null);
    StudentEntry? enrolled;
    for (final row in enrollments) {
      try {
        enrolled = StudentEntry.fromJson({
          ...row,
          'full_name': row['full_name'] ?? person.fullName,
          'person': row['person'] ?? person.raw,
        });
        break;
      } on FormatException {
        continue;
      }
    }
    final student = StudentEntry(
      id: enrolled?.id ?? 0,
      personId: person.id,
      fullName: person.fullName,
      nickname: enrolled?.nickname,
      code: person.code ?? enrolled?.code,
      pictureUrl: person.pictureUrl ?? enrolled?.pictureUrl,
      status: enrolled?.status,
      groupId: enrolled?.groupId,
      classPair: enrolled?.classPair,
      details: PersonDetails.fromJson(person.raw),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              child: builder(
                context,
                student,
                student.classPair ?? '',
                () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final tokens = tokenizeSearch(_query.text);
    final browsing = tokens.isEmpty;
    final entries = _matches(l, tokens);
    final term = _query.text.trim();
    final peopleWaiting = _peopleOn && term.length >= minPeopleQuery;
    final nothing =
        !browsing &&
        entries.isEmpty &&
        _people.isEmpty &&
        !_loading &&
        _error == null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('search-field'),
                      controller: _query,
                      autofocus: true,
                      onChanged: _onChanged,
                      textInputAction: TextInputAction.search,
                      autocorrect: false,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _peopleOn ? l.searchHint : l.searchPagesHint,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colors.mutedText,
                        ),
                        suffixIcon: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _query.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _query.clear();
                                  _onChanged('');
                                },
                              ),
                        filled: true,
                        fillColor: colors.softBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  if (entries.isNotEmpty) ...[
                    _Heading(browsing ? l.searchSuggested : l.searchPages),
                    for (final entry in entries)
                      _Row(
                        key: ValueKey('search-${entry.id}'),
                        icon: _icon(entry),
                        title: _title(l, entry),
                        tokens: tokens,
                        onTap: () => _openEntry(entry),
                      ),
                  ],
                  if (_people.isNotEmpty) ...[
                    _Heading(
                      _total > _people.length
                          ? '${l.searchPeople} · ${l.searchFound(_total)}'
                          : l.searchPeople,
                    ),
                    for (final person in _people)
                      _PersonRow(
                        key: ValueKey('person-${person.id}'),
                        person: person,
                        tokens: tokens,
                        opening: _opening == person.id,
                        onTap: () => _openPerson(person),
                      ),
                    if (_page < _pages && _term == term)
                      Align(
                        child: TextButton(
                          onPressed: _loadingMore
                              ? null
                              : () => _search(_term, _page + 1),
                          child: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l.searchShowMore),
                        ),
                      ),
                  ],
                  if (_error != null && peopleWaiting)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: colors.mutedText),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _search(term, 1),
                            child: Text(l.retry),
                          ),
                        ],
                      ),
                    ),
                  if (_peopleOn && !browsing && term.length < minPeopleQuery)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        l.searchMinChars(minPeopleQuery),
                        style: TextStyle(fontSize: 12, color: colors.mutedText),
                      ),
                    ),
                  if (nothing)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 32,
                            color: colors.mutedText,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.searchNothing(term),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _peopleOn
                                ? l.searchNothingBody
                                : l.searchNothingPagesBody,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: appColorsOf(context).mutedText,
      ),
    ),
  );
}

/// [text] with the query words in bold.
class _Highlighted extends StatelessWidget {
  const _Highlighted(this.text, this.tokens, {this.style});

  final String text;
  final List<String> tokens;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final ranges = searchRanges(text, tokens);
    if (ranges.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }
    final strong = base.copyWith(
      fontWeight: FontWeight.w800,
      color: appColorsOf(context).accent.solid,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in ranges) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: strong));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.title,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<String> tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.accent.solid),
            const SizedBox(width: 12),
            Expanded(
              child: _Highlighted(
                title,
                tokens,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: colors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.person,
    required this.tokens,
    required this.opening,
    required this.onTap,
  });

  final PersonHit person;
  final List<String> tokens;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final muted = TextStyle(fontSize: 12, color: colors.mutedText);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _Highlighted(
                person.fullName,
                tokens,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: person.left ? colors.mutedText : null,
                ),
              ),
            ),
            if (person.left) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.softBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l.searchLeft,
                  style: muted.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (person.grade != null) ...[
              const SizedBox(width: 8),
              Text(l.searchGrade(person.grade!), style: muted),
            ],
            if (person.code != null) ...[
              const SizedBox(width: 8),
              _Highlighted(
                person.code!,
                tokens,
                style: muted.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(width: 4),
            opening
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.mutedText,
                  ),
          ],
        ),
      ),
    );
  }
}
