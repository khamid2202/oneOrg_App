import 'dart:convert';
import 'dart:math';

class ToolStudent {
  const ToolStudent({required this.id, required this.name});

  final String id;
  final String name;
}

/// Handed out in this order; members past the eighth are helpers.
const teamRoles = [
  'leader',
  'timekeeper',
  'recorder',
  'reporter',
  'checker',
  'encourager',
  'materials',
  'questioner',
];
const helperRole = 'helper';

/// As many teams as there are colours.
const maxTeams = 8;

String _pairKey(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

/// Per class: who was together last time, each student's last role, and how
/// often they've had each role.
class TeamHistory {
  const TeamHistory({
    this.pairs = const {},
    this.lastRole = const {},
    this.roleCounts = const {},
  });

  final Set<String> pairs;
  final Map<String, String> lastRole;
  final Map<String, Map<String, int>> roleCounts;

  String encode() => jsonEncode({
    'pairs': pairs.toList(),
    'lastRole': lastRole,
    'roleCounts': roleCounts,
  });

  /// A broken or missing record is just no history.
  factory TeamHistory.decode(String? raw) {
    if (raw == null) return const TeamHistory();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return TeamHistory(
        pairs: (json['pairs'] as List).cast<String>().toSet(),
        lastRole: (json['lastRole'] as Map).cast<String, String>(),
        roleCounts: (json['roleCounts'] as Map).map(
          (id, counts) =>
              MapEntry(id as String, (counts as Map).cast<String, int>()),
        ),
      );
    } catch (_) {
      return const TeamHistory();
    }
  }
}

class Team {
  const Team({required this.members, required this.roles});

  final List<ToolStudent> members;

  /// Student id → role.
  final Map<String, String> roles;

  /// Leader first, helpers last.
  List<ToolStudent> get byRole {
    int rank(ToolStudent s) {
      final index = teamRoles.indexOf(roles[s.id] ?? helperRole);
      return index == -1 ? teamRoles.length : index;
    }

    return members.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
  }
}

Iterable<String> _pairsOf(List<ToolStudent> members) sync* {
  for (var i = 0; i < members.length; i++) {
    for (var j = i + 1; j < members.length; j++) {
      yield _pairKey(members[i].id, members[j].id);
    }
  }
}

/// Roles rotate: nobody gets last time's role if it can be helped, and a role
/// someone has had often goes to somebody else.
Map<String, String> _assignRoles(
  List<ToolStudent> members,
  TeamHistory history,
  Random random,
) {
  final names = [
    for (var i = 0; i < members.length; i++)
      i < teamRoles.length ? teamRoles[i] : helperRole,
  ];
  List<ToolStudent>? best;
  var bestCost = double.infinity;
  for (var tries = 0; tries < 60; tries++) {
    final order = members.toList()..shuffle(random);
    var cost = random.nextDouble();
    for (var i = 0; i < order.length; i++) {
      final id = order[i].id;
      if (history.lastRole[id] == names[i]) cost += 10;
      cost += (history.roleCounts[id]?[names[i]] ?? 0) * 3;
    }
    if (cost < bestCost) {
      bestCost = cost;
      best = order;
    }
  }
  return {for (var i = 0; i < best!.length; i++) best[i].id: names[i]};
}

/// Of a few random deals, keeps the one repeating the fewest pairs from last
/// time, then hands out the roles.
List<Team> makeTeams(
  List<ToolStudent> students,
  int count,
  TeamHistory history, {
  Random? random,
}) {
  final dice = random ?? Random();
  List<List<ToolStudent>>? best;
  var bestRepeats = 1 << 30;
  for (var tries = 0; tries < 40 && bestRepeats > 0; tries++) {
    final teams = List.generate(count, (_) => <ToolStudent>[]);
    final dealt = students.toList()..shuffle(dice);
    for (var i = 0; i < dealt.length; i++) {
      teams[i % count].add(dealt[i]);
    }
    final repeats = teams.expand(_pairsOf).where(history.pairs.contains).length;
    if (repeats < bestRepeats) {
      bestRepeats = repeats;
      best = teams;
    }
  }
  return [
    for (final members in best!)
      Team(members: members, roles: _assignRoles(members, history, dice)),
  ];
}

/// [history] after this shuffle. Roles only count when they were shown.
TeamHistory afterShuffle(
  TeamHistory history,
  List<Team> teams, {
  required bool rolesShown,
}) {
  final pairs = teams.map((t) => t.members).expand(_pairsOf).toSet();
  if (!rolesShown) {
    return TeamHistory(
      pairs: pairs,
      lastRole: history.lastRole,
      roleCounts: history.roleCounts,
    );
  }
  final lastRole = {...history.lastRole};
  final counts = {
    for (final entry in history.roleCounts.entries) entry.key: {...entry.value},
  };
  for (final team in teams) {
    team.roles.forEach((id, role) {
      lastRole[id] = role;
      final mine = counts[id] ??= {};
      mine[role] = (mine[role] ?? 0) + 1;
    });
  }
  return TeamHistory(pairs: pairs, lastRole: lastRole, roleCounts: counts);
}

/// The next name: someone not picked yet this round. Once everyone has had a
/// turn the round starts again, which is why [picked] comes back too.
(ToolStudent, List<String>)? pickNext(
  List<ToolStudent> present,
  List<String> picked, {
  Random? random,
}) {
  var pool = present.where((s) => !picked.contains(s.id)).toList();
  var done = picked;
  if (pool.isEmpty) {
    pool = present;
    done = const [];
  }
  if (pool.isEmpty) return null;
  final winner = pool[(random ?? Random()).nextInt(pool.length)];
  return (winner, [...done, winner.id]);
}
