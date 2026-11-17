/// A campus of the school (docs/staff/branches.md).
class Branch {
  const Branch({required this.id, required this.name, this.isActive = true});

  final int id;
  final String name;
  final bool isActive;

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      isActive: json['is_active'] != false,
    );
  }
}

abstract class BranchesRepository {
  /// The branches this user can select. Null when the API predates branches,
  /// in which case the app runs without selecting one.
  Future<List<Branch>?> getMyBranches(String token);
}
