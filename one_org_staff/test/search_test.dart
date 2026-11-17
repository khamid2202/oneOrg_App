import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/landing/domain/app_items.dart';
import 'package:one_org_staff/features/landing/presentation/coming_soon.dart';
import 'package:one_org_staff/features/search/data/http_search_repository.dart';
import 'package:one_org_staff/features/search/domain/app_search.dart';
import 'package:one_org_staff/features/search/presentation/search_page.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';

AppUserProfile _teacher() => const AppUserProfile(
  id: 1,
  fullName: 'Ali Valiyev',
  subtitle: '',
  email: '',
  phone: '',
  department: '',
  joinedDate: '',
  roles: ['teacher'],
  permissions: ['behavior.read'],
);

Widget _app(Widget home) => MaterialApp(
  theme: buildAppTheme(
    accent: kDefaultAccent,
    brightness: Brightness.light,
    darkVariant: kDefaultDarkVariant,
  ),
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class _FakeSearch implements SearchRepository {
  final terms = <String>[];
  List<Map<String, dynamic>> enrollments = const [];

  @override
  Future<PersonPage> searchPeople(String term, {int page = 1}) async {
    terms.add(term);
    return const PersonPage(
      people: [
        PersonHit(
          id: 7,
          fullName: 'Alisher Karimov',
          code: 'DIS250007',
          grade: 9,
        ),
        PersonHit(id: 8, fullName: 'Aliya Nur', code: 'DIS240008', left: true),
      ],
      total: 2,
      pages: 1,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> enrollmentsOf(int personId) async =>
      enrollments;
}

/// A home screen that opens [page], so the search can pop back to it.
Widget _host(Widget page) => _app(
  Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page)),
        child: const Text('open'),
      ),
    ),
  ),
);

double _score(String title, List<String> keywords, String query) =>
    scoreSearchEntry([title], keywords, tokenizeSearch(query), query);

void main() {
  group('matcher', () {
    test(
      'finds a screen by title start, keyword, other language or abbreviation',
      () {
        expect(_score('Timetable', const [], 'time'), greaterThan(0));
        expect(
          _score('My Schedule', const ['davomat'], 'davomat'),
          greaterThan(0),
        );
        expect(_score('Timetable', const [], 'tmtbl'), greaterThan(0));
        expect(_score('Timetable', const [], 'xyz'), 0);
      },
    );

    test('short words only match at the start of a word', () {
      // "ali" is a name search, not the end of "jadvali".
      expect(_score('Dars jadvali', const [], 'ali'), 0);
      expect(_score('Dars jadvali', const [], 'jad'), greaterThan(0));
      expect(_score('My Points', const ['ballar'], 'ali'), 0);
    });

    test('every word has to land somewhere', () {
      expect(_score('Point Report', const [], 'point exam'), 0);
      expect(_score('Point Report', const [], 'point rep'), greaterThan(0));
    });

    test('title hits beat keyword hits, and apostrophes are ignored', () {
      expect(
        _score('Report', const [], 'report'),
        greaterThan(_score('Point Report', const ['report'], 'report')),
      );
      expect(_score('O‘quvchilar', const [], "o'quv"), greaterThan(0));
    });

    test('highlights merge overlapping hits', () {
      expect(searchRanges('Point Report', const ['po', 'point']), [
        (0, 5),
        (8, 10),
      ]);
    });

    test('My Plan and Rewards are not offered while switched off', () {
      final items = searchCatalog.map((e) => e.item);
      expect(items, isNot(contains(AppItem.myPlan)));
      expect(items, isNot(contains(AppItem.rewards)));
    });
  });

  group('HttpSearchRepository', () {
    test(
      'searches persons and marks the ones whose latest enrollment left',
      () async {
        final asked = <Uri>[];
        final repo = HttpSearchRepository(
          client: MockClient((request) async {
            asked.add(request.url);
            if (request.url.path == '/students') {
              return http.Response(
                jsonEncode({
                  'result': [
                    {
                      'id': 1,
                      'person_id': 8,
                      'status': 'present',
                      'join_date': '2024-09-01',
                    },
                    {
                      'id': 2,
                      'person_id': 8,
                      'status': 'left',
                      'join_date': '2025-09-01',
                    },
                    {
                      'id': 3,
                      'person_id': 7,
                      'status': 'left',
                      'join_date': '2024-09-01',
                    },
                    {
                      'id': 4,
                      'person_id': 7,
                      'status': 'present',
                      'join_date': '2025-09-01',
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'result': [
                  {
                    'id': 7,
                    'full_name': 'Alisher',
                    'code': 'DIS250007',
                    'grade': 9,
                  },
                  {'id': 8, 'full_name': 'Aliya', 'code': 'DIS240008'},
                  {'id': 9, 'full_name': ''},
                ],
                'meta': {'total': 30, 'pages': 2},
              }),
              200,
            );
          }),
          baseUrl: 'https://api.test/',
          readToken: () async => 'token',
        );

        final page = await repo.searchPeople(' ali ');
        final persons = asked.firstWhere((u) => u.path == '/persons');
        expect(persons.queryParameters, {
          'search': 'ali',
          'page': '1',
          'limit': '25',
        });
        expect(page.people.map((p) => p.id), [7, 8]);
        expect(page.people.map((p) => p.left), [false, true]);
        expect(page.total, 30);
        expect(page.pages, 2);

        // The left ids are asked once per term.
        await repo.searchPeople('ali', page: 2);
        expect(asked.where((u) => u.path == '/students'), hasLength(1));
      },
    );

    test('a 403 means people search is locked', () async {
      final repo = HttpSearchRepository(
        client: MockClient((_) async => http.Response('{}', 403)),
        baseUrl: 'https://api.test',
        readToken: () async => 'token',
      );
      expect(repo.searchPeople('ali'), throwsA(isA<SearchLocked>()));
    });

    test('enrollments come back newest first', () async {
      final repo = HttpSearchRepository(
        client: MockClient((request) async {
          expect(request.url.queryParameters['person_id'], '7');
          return http.Response(
            jsonEncode({
              'result': [
                {'id': 1, 'join_date': '2024-09-01'},
                {'id': 3, 'join_date': '2025-09-01'},
                {'id': 2, 'join_date': '2025-09-01'},
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://api.test',
        readToken: () async => 'token',
      );
      final rows = await repo.enrollmentsOf(7);
      expect(rows.map((r) => r['id']), [3, 2, 1]);
    });
  });

  group('SearchPage', () {
    testWidgets('suggests the screens this person can open', (tester) async {
      await tester.pumpWidget(
        _app(
          SearchPage(
            access: AppAccess(_teacher()),
            onOpenItem: (_) {},
            onOpenPlace: (_) {},
          ),
        ),
      );
      expect(find.text('SUGGESTED'), findsOneWidget);
      expect(find.byKey(const ValueKey('search-lessons')), findsOneWidget);
      expect(find.byKey(const ValueKey('search-myPlan')), findsNothing);
      // Rewards is switched off.
      expect(find.byKey(const ValueKey('search-rewards')), findsNothing);
      // No push service, so no notifications screen.
      expect(find.byKey(const ValueKey('search-notifications')), findsNothing);
    });

    testWidgets('opens a screen and closes itself', (tester) async {
      AppItem? opened;
      await tester.pumpWidget(
        _host(
          SearchPage(
            access: AppAccess(_teacher()),
            onOpenItem: (item) => opened = item,
            onOpenPlace: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('search-field')),
        'hamkasb',
      );
      await tester.pump();
      expect(find.text('PAGES'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('search-colleagues')));
      await tester.pumpAndSettle();
      expect(opened, AppItem.colleagues);
      expect(find.byType(SearchPage), findsNothing);
    });

    testWidgets('finds people after two letters and opens their profile', (
      tester,
    ) async {
      final repo = _FakeSearch()
        ..enrollments = [
          {
            'id': 70,
            'person_id': 7,
            'status': 'present',
            'group': {'id': 3, 'grade': 9, 'class': 'B'},
          },
        ];
      StudentEntry? shown;
      String? shownClass;
      await tester.pumpWidget(
        _app(
          SearchPage(
            access: AppAccess(_teacher()),
            onOpenItem: (_) {},
            onOpenPlace: (_) {},
            repository: repo,
            canSearchPeople: true,
            debounce: Duration.zero,
            profileBuilder: (context, student, classPair, onBack) {
              shown = student;
              shownClass = classPair;
              return TextButton(
                onPressed: onBack,
                child: const Text('profile'),
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byKey(const ValueKey('search-field')), 'a');
      await tester.pump();
      expect(find.text('Type 2 letters to search people'), findsOneWidget);
      expect(repo.terms, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('search-field')), 'ali');
      await tester.pump();
      await tester.pump();
      expect(repo.terms, ['ali']);
      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.byKey(const ValueKey('person-7')), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Grade 9'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('person-7')));
      await tester.pumpAndSettle();
      expect(find.text('profile'), findsOneWidget);
      expect(shown?.id, 70);
      expect(shown?.personId, 7);
      expect(shown?.code, 'DIS250007');
      expect(shownClass, '9-B');

      await tester.tap(find.text('profile'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);
    });

    testWidgets('without people access only screens are searched', (
      tester,
    ) async {
      final repo = _FakeSearch();
      await tester.pumpWidget(
        _app(
          SearchPage(
            access: AppAccess(_teacher()),
            onOpenItem: (_) {},
            onOpenPlace: (_) {},
            repository: repo,
            debounce: Duration.zero,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('search-field')),
        'zzzz',
      );
      await tester.pump();
      await tester.pump();
      expect(repo.terms, isEmpty);
      expect(find.text('Nothing found for “zzzz”'), findsOneWidget);
      expect(find.text('Try another word for the page.'), findsOneWidget);
    });
  });

  testWidgets('Coming soon names the page', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: ComingSoonPage(title: 'My Plan', icon: Icons.edit_note_rounded),
        ),
      ),
    );
    expect(find.text('My Plan'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
