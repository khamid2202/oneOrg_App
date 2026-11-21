import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/landing/domain/app_items.dart';
import 'package:one_org_staff/features/landing/presentation/updates_card.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:one_org_staff/shared/api_client.dart';

/// An API that answers every list with [rows] for its path, or nothing.
ApiClient _api([Map<String, List<Map<String, Object?>>> rows = const {}]) =>
    ApiClient(
      client: MockClient(
        (req) async => http.Response(
          jsonEncode({'result': rows[req.url.path] ?? const []}),
          200,
        ),
      ),
      baseUrl: 'https://api.test',
      readToken: () async => 't',
    );

WhatsNewEntry _news(String id, String date, {AppItem? opens}) => WhatsNewEntry(
  id: id,
  date: date,
  title: (_) => 'Title $id',
  body: (_) => 'Body $id',
  opens: opens,
);

void main() {
  final l = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 11, 19, 15);

  test('what\'s new shows for two weeks, then drops off', () async {
    final items = await loadUpdates(
      _api(),
      1,
      l,
      'en',
      clock: now,
      news: [
        _news('fresh', '2026-11-18', opens: AppItem.calendar),
        _news('old', '2026-10-01'),
      ],
    );
    expect(items.map((i) => i.id), ['news-fresh']);
    expect(items.single.kind, 'news');
    expect(items.single.title, 'Title fresh');
    expect(items.single.detail, 'Body fresh');
    expect(items.single.opens, AppItem.calendar);
  });

  test('news sits among the other updates by date', () async {
    final items = await loadUpdates(
      _api({
        '/user-points': [
          {'id': 7, 'points': 3, 'created_at': '2026-11-19T09:00:00'},
        ],
      }),
      1,
      l,
      'en',
      clock: now,
      news: [_news('a', '2026-11-17')],
    );
    expect(items.map((i) => i.id), ['point-7', 'news-a']);
  });

  test('Updates includes unread notifications only', () async {
    final items = await loadUpdates(
      _api({
        '/notifications': [
          {
            'id': 1,
            'is_read': true,
            'title': 'Read',
            'created_at': '2026-11-19T09:00:00',
          },
          {
            'id': 2,
            'is_read': false,
            'title': 'Unread',
            'created_at': '2026-11-19T10:00:00',
          },
        ],
      }),
      1,
      l,
      'en',
      clock: now,
      news: [],
    );
    expect(items.map((item) => item.title), ['Unread']);
  });

  test('a news entry dated today does not claim to be in the future', () async {
    final items = await loadUpdates(
      _api(),
      1,
      l,
      'en',
      clock: DateTime(2026, 11, 19, 8),
      news: [_news('today', '2026-11-19')],
    );
    expect(items.single.when, l.calToday);
  });

  test('every shipped entry has a real date and text', () {
    for (final n in whatsNew) {
      expect(DateTime.tryParse(n.date), isNotNull, reason: n.id);
      expect(n.title(l), isNotEmpty, reason: n.id);
      expect(n.body(l), isNotEmpty, reason: n.id);
    }
  });
}
