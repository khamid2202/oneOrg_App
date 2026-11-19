import '../../landing/domain/app_items.dart';

/// Screens that aren't [AppItem]s but can still be searched for.
enum SearchPlace { home, profile, notifications }

/// One searchable screen. Exactly one of [item] and [place] is set.
class SearchEntry {
  const SearchEntry.item(AppItem this.item, this.keywords) : place = null;
  const SearchEntry.place(SearchPlace this.place, this.keywords) : item = null;

  final AppItem? item;
  final SearchPlace? place;

  /// Other words people use for it, in English, Uzbek and Russian. Staff mix
  /// the three, so all of them are searched whatever the app's language is.
  final List<String> keywords;

  String get id => item?.name ?? place!.name;
}

/// Every screen the search can open, in the order they're suggested.
/// My Plan and Rewards are left out while they're switched off.
const searchCatalog = [
  SearchEntry.item(AppItem.lessons, [
    'attendance',
    'scores',
    'lesson',
    'today',
    'schedule',
    'davomat',
    'baho',
    'dars',
    'jadval',
    'посещаемость',
    'оценки',
    'урок',
    'расписание',
  ]),
  SearchEntry.item(AppItem.myClass, [
    'homeroom',
    'students',
    'roster',
    'contacts',
    'guardians',
    'parents',
    'sinf',
    'oquvchilar',
    'ota-ona',
    'rahbar',
    'класс',
    'ученики',
    'родители',
    'классный',
  ]),
  SearchEntry.item(AppItem.grades, [
    'gradebook',
    'marks',
    'scores',
    'baholar',
    'jurnal',
    'журнал',
    'оценки',
  ]),
  SearchEntry.item(AppItem.behavior, [
    'behavior',
    'behaviour',
    'report',
    'discipline',
    'incident',
    'xulq',
    'intizom',
    'hisobot',
    'поведение',
    'замечание',
    'дисциплина',
  ]),
  SearchEntry.item(AppItem.teachingTools, [
    'team',
    'shuffle',
    'groups',
    'name picker',
    'random',
    'timer',
    'jamoa',
    'guruh',
    'tasodifiy',
    'taymer',
    'команды',
    'группы',
    'случайный',
    'таймер',
  ]),
  SearchEntry.item(AppItem.myPoints, [
    'points',
    'balance',
    'bonus',
    'ballar',
    'balans',
    'баллы',
    'баланс',
  ]),
  SearchEntry.item(AppItem.myFundings, [
    'savings',
    'money',
    'funding',
    'travel',
    'jamgarma',
    'pul',
    'sayohat',
    'накопления',
    'деньги',
    'путешествия',
  ]),
  SearchEntry.item(AppItem.exams, [
    'exam',
    'test',
    'results',
    'imtihon',
    'natija',
    'экзамен',
    'результаты',
  ]),
  SearchEntry.item(AppItem.timetable, [
    'schedule',
    'periods',
    'week',
    'dars jadvali',
    'hafta',
    'расписание',
    'неделя',
  ]),
  SearchEntry.item(AppItem.colleagues, [
    'staff',
    'teachers',
    'phone',
    'call',
    'contacts',
    'hamkasblar',
    'xodimlar',
    'oqituvchilar',
    'telefon',
    'коллеги',
    'сотрудники',
    'учителя',
    'телефон',
  ]),
  SearchEntry.item(AppItem.pointReport, [
    'report',
    'statistics',
    'points report',
    'hisobot',
    'statistika',
    'отчёт',
    'отчет',
    'статистика',
  ]),
  SearchEntry.item(AppItem.calendar, [
    'calendar',
    'events',
    'holidays',
    'term',
    'kalendar',
    'tadbirlar',
    'bayram',
    'bayramlar',
    'taqvim',
    'календарь',
    'события',
    'праздники',
  ]),
  SearchEntry.item(AppItem.myLessonAnalysis, [
    'analysis',
    'lesson analysis',
    'dars tahlili',
    'observation',
    'feedback',
    'tahlil',
    'kuzatuv',
    'анализ',
    'наблюдение',
  ]),
  SearchEntry.item(AppItem.lessonAnalysis, [
    'analysis',
    'observation',
    'kpi',
    'tahlil',
    'kuzatuv',
    'анализ урока',
    'наблюдение',
  ]),
  SearchEntry.item(AppItem.myDepartment, [
    'department',
    'hod',
    'statistics',
    'kafedra',
    'bolim',
    'кафедра',
    'отдел',
  ]),
  SearchEntry.item(AppItem.substitutions, [
    'substitution',
    'cover',
    'absence',
    'almashtirish',
    'yoqlik',
    'замена',
    'отсутствие',
  ]),
  SearchEntry.item(AppItem.attendanceCheck, [
    'attendance',
    'marked',
    'davomat',
    'посещаемость',
  ]),
  SearchEntry.item(AppItem.cashier, [
    'cashier',
    'dollars',
    'dombit',
    'balance',
    'kassa',
    'dollar',
    'касса',
    'доллары',
  ]),
  SearchEntry.item(AppItem.staffPoints, [
    'staff points',
    'award',
    'deduct',
    'xodim ballari',
    'баллы сотрудников',
  ]),
  SearchEntry.item(AppItem.fundings, [
    'fundings',
    'savings',
    'deposit',
    'jamgarma',
    'накопления',
    'взнос',
  ]),
  SearchEntry.place(SearchPlace.home, [
    'dashboard',
    'today',
    'start',
    'bosh sahifa',
    'asosiy',
    'главная',
  ]),
  SearchEntry.place(SearchPlace.notifications, [
    'alerts',
    'messages',
    'bell',
    'bildirishnomalar',
    'xabarlar',
    'уведомления',
    'сообщения',
  ]),
  SearchEntry.place(SearchPlace.profile, [
    'account',
    'password',
    'photo',
    'language',
    'theme',
    'dark mode',
    'colour',
    'color',
    'sign out',
    'logout',
    'parol',
    'rasm',
    'til',
    'mavzu',
    'tungi rejim',
    'chiqish',
    'аккаунт',
    'пароль',
    'фото',
    'язык',
    'тема',
    'тёмная',
    'выход',
  ]),
];

// Uzbek Latin writes oʻ/gʻ with a modifier letter, and people type any of these.
final _apostrophes = RegExp('[ʻʼ‘’\'`]');
final _separators = RegExp(r'[\s/_.,-]+');

/// Case- and apostrophe-insensitive form used for every comparison.
String normalizeSearch(String value) => value
    .replaceAll(_apostrophes, '')
    .toLowerCase()
    .replaceAll('ё', 'е')
    .trim();

/// The words that must each find a home in an entry.
List<String> tokenizeSearch(String query) => normalizeSearch(
  query,
).split(_separators).where((word) => word.isNotEmpty).toList();

/// `tmtbl` finds "timetable": letters in order, close enough together.
double _subsequence(String haystack, String token) {
  if (token.length < 3) return 0;
  var start = -1;
  var cursor = 0;
  for (var i = 0; i < haystack.length && cursor < token.length; i++) {
    if (haystack[i] != token[cursor]) continue;
    if (cursor == 0) start = i;
    cursor++;
    if (cursor == token.length) {
      final span = i - start + 1;
      if (span > token.length * 2.4) return 0;
      return 12 + 16 * (token.length / span);
    }
  }
  return 0;
}

double _scoreToken(String haystack, String token, {required bool fuzzy}) {
  if (haystack.isEmpty) return 0;
  if (haystack == token) return 100;
  if (haystack.startsWith(token)) return 88;
  // A short word like "ali" is usually part of a name, and inside another
  // word ("jadvali") it would drag in screens nobody meant. Short words only
  // count at the start of a word.
  final short = token.length < 4;
  for (var at = haystack.indexOf(token); at > 0 && short;) {
    if (_separators.hasMatch(haystack[at - 1])) return 72;
    at = haystack.indexOf(token, at + 1);
  }
  if (short) return 0;
  final at = haystack.indexOf(token);
  if (at > 0) {
    // "report" in "point report" is meant; "port" in "report" mostly isn't.
    return _separators.hasMatch(haystack[at - 1]) ? 72 : 48;
  }
  return fuzzy ? _subsequence(haystack, token) : 0;
}

/// How well [entry] fits the query. Its [titles] are its names in every
/// language, the one on screen first. 0 means some word matched nothing.
double scoreSearchEntry(
  List<String> titles,
  List<String> keywords,
  List<String> tokens,
  String rawQuery,
) {
  if (tokens.isEmpty || titles.isEmpty) return 0;
  final names = titles.map(normalizeSearch).toList();
  final words = keywords.map(normalizeSearch).toList();
  var total = 0.0;
  for (final token in tokens) {
    var best = 0.0;
    for (final name in names) {
      final score = _scoreToken(name, token, fuzzy: true);
      if (score > best) best = score;
    }
    for (final word in words) {
      final score = 0.78 * _scoreToken(word, token, fuzzy: true);
      if (score > best) best = score;
    }
    if (best == 0) return 0;
    total += best;
  }
  var score = total / tokens.length;
  final query = normalizeSearch(rawQuery);
  final shown = names.first;
  if (query.isNotEmpty && shown.startsWith(query)) score += 30;
  if (query.isNotEmpty && shown == query) score += 60;
  // All else equal, the shorter, more general screen is the one meant.
  score -= (shown.length < 40 ? shown.length : 40) * 0.15;
  return score;
}

/// Where in [text] the query words land, merged, for highlighting.
List<(int, int)> searchRanges(String text, List<String> tokens) {
  // Only the lowercasing is length-safe, so highlight on that alone.
  final haystack = text.toLowerCase();
  final ranges = <(int, int)>[];
  for (final token in tokens) {
    var from = 0;
    while (true) {
      final at = haystack.indexOf(token, from);
      if (at == -1) break;
      ranges.add((at, at + token.length));
      from = at + token.length;
    }
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = <(int, int)>[];
  for (final range in ranges) {
    if (merged.isNotEmpty && range.$1 <= merged.last.$2) {
      final last = merged.removeLast();
      merged.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2));
    } else {
      merged.add(range);
    }
  }
  return merged;
}

/// Someone found by name or code.
class PersonHit {
  const PersonHit({
    required this.id,
    required this.fullName,
    this.code,
    this.grade,
    this.pictureUrl,
    this.left = false,
    this.raw = const {},
  });

  final int id;
  final String fullName;
  final String? code;
  final int? grade;
  final String? pictureUrl;

  /// Their latest enrollment is marked as left.
  final bool left;

  /// The whole person record, for the profile it opens.
  final Map<String, dynamic> raw;

  static PersonHit? fromJson(Map<String, dynamic> json, {bool left = false}) {
    final id = num.tryParse('${json['id']}')?.toInt();
    final name = json['full_name']?.toString().trim() ?? '';
    if (id == null || name.isEmpty) return null;
    final code = json['code']?.toString().trim();
    final picture = json['picture_url']?.toString().trim();
    return PersonHit(
      id: id,
      fullName: name,
      code: code == null || code.isEmpty ? null : code,
      grade: num.tryParse('${json['grade']}')?.toInt(),
      pictureUrl: picture == null || picture.isEmpty ? null : picture,
      left: left,
      raw: json,
    );
  }
}

class PersonPage {
  const PersonPage({
    required this.people,
    required this.total,
    required this.pages,
  });

  final List<PersonHit> people;
  final int total;
  final int pages;
}

/// The search asks the server two things: who matches, and — once one is
/// picked — which enrollments that person has.
abstract class SearchRepository {
  /// `/persons?search=`, which matches `full_name` or `code`.
  Future<PersonPage> searchPeople(String term, {int page = 1});

  /// Raw `/students?person_id=` rows, newest first.
  Future<List<Map<String, dynamic>>> enrollmentsOf(int personId);
}

/// Thrown when this person may not search people at all.
class SearchLocked implements Exception {
  const SearchLocked();
}

const minPeopleQuery = 2;
