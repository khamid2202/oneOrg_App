import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/branches_repository.dart';

enum BranchStatus { loading, ready, none, error }

/// Holds the branch the teacher is working in. It is resolved before any
/// screen fetches data, because without a selection a teacher at several
/// branches gets all of them mixed together, and class names like "7-A" repeat
/// across branches.
class BranchController extends ChangeNotifier {
  BranchController({
    required Future<List<Branch>?> Function() loadBranches,
    SharedPreferences? preferences,
    DateTime Function()? clock,
  }) : _loadBranches = loadBranches,
       _preferences = preferences,
       _clock = clock ?? DateTime.now;

  static const _savedKey = 'active_branch_id';

  /// A branch that keeps being refused must not turn into a reload loop.
  static const _recoveryCooldown = Duration(seconds: 10);

  final Future<List<Branch>?> Function() _loadBranches;
  final DateTime Function() _clock;
  SharedPreferences? _preferences;

  BranchStatus _status = BranchStatus.loading;
  List<Branch> _branches = const [];
  int? _activeBranchId;
  int _loadTicket = 0;
  DateTime? _lastRecovery;

  BranchStatus get status => _status;

  List<Branch> get branches => _branches;

  /// Null until resolved, and when the API predates branches.
  int? get activeBranchId => _activeBranchId;

  /// Null when the list could not be loaded and a saved id is in use.
  Branch? get activeBranch {
    for (final branch in _branches) {
      if (branch.id == _activeBranchId) {
        return branch;
      }
    }
    return null;
  }

  bool get canSwitch => _branches.length > 1;

  Future<void> load() async {
    final ticket = ++_loadTicket;
    if (_status != BranchStatus.loading) {
      _status = BranchStatus.loading;
      notifyListeners();
    }

    final savedId = await _readSavedId();
    List<Branch>? loaded;
    try {
      loaded = await _loadBranches().timeout(const Duration(seconds: 12));
    } catch (_) {
      if (ticket != _loadTicket) {
        return;
      }
      // A saved branch still works on a poor connection. If it has gone stale
      // the first refused request brings the teacher back here.
      _activeBranchId = savedId;
      _status = savedId != null ? BranchStatus.ready : BranchStatus.error;
      notifyListeners();
      return;
    }
    if (ticket != _loadTicket) {
      return;
    }

    if (loaded == null) {
      _status = BranchStatus.ready;
    } else if (loaded.isEmpty) {
      _status = BranchStatus.none;
    } else {
      _branches = loaded;
      _activeBranchId = _pick(loaded, savedId);
      _status = BranchStatus.ready;
      unawaited(_save(_activeBranchId));
    }
    notifyListeners();
  }

  /// Open tabs load their data when they mount, and the switcher only lives on
  /// the dashboard, so no screen is left showing the previous branch.
  void switchTo(int branchId) {
    if (branchId == _activeBranchId ||
        !_branches.any((branch) => branch.id == branchId)) {
      return;
    }
    _activeBranchId = branchId;
    unawaited(_save(branchId));
    notifyListeners();
  }

  /// The selected branch was deactivated or the teacher was removed from it
  /// while the app was open: drop it and resolve again.
  void handleBranchRejected() {
    final now = _clock();
    final last = _lastRecovery;
    if (last != null && now.difference(last) < _recoveryCooldown) {
      return;
    }
    _lastRecovery = now;
    _activeBranchId = null;
    _branches = const [];
    unawaited(_save(null).then((_) => load()));
  }

  /// Clears the session's state on sign-out. The saved id stays: it is checked
  /// against the next user's own branches before it is used.
  void reset() {
    _loadTicket += 1;
    _status = BranchStatus.loading;
    _branches = const [];
    _activeBranchId = null;
    _lastRecovery = null;
  }

  /// The saved branch if it is still on offer, else the oldest active one.
  static int _pick(List<Branch> branches, int? savedId) {
    if (branches.any((branch) => branch.id == savedId)) {
      return savedId!;
    }
    final byAge = [...branches]..sort((a, b) => a.id.compareTo(b.id));
    return byAge
        .firstWhere((branch) => branch.isActive, orElse: () => byAge.first)
        .id;
  }

  Future<SharedPreferences?> get _prefs async {
    try {
      return _preferences ??= await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readSavedId() async {
    try {
      return (await _prefs)?.getInt(_savedKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save(int? branchId) async {
    final prefs = await _prefs;
    if (branchId == null) {
      await prefs?.remove(_savedKey);
    } else {
      await prefs?.setInt(_savedKey, branchId);
    }
  }
}
