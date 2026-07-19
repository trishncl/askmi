import '../../models/user_model.dart';

/// null = "All Roles" / "All Status" — kept nullable rather than a sentinel
/// string so the filter bar's dropdown can show a real "All ..." item
/// without colliding with an actual role/status value.
enum UserSort { name, recentlyAdded, oldest, role }

extension UserSortLabel on UserSort {
  String get label => switch (this) {
        UserSort.name => 'Name',
        UserSort.recentlyAdded => 'Recently Added',
        UserSort.oldest => 'Oldest',
        UserSort.role => 'Role',
      };
}

/// All list-narrowing state for the User Management screen in one place —
/// same split as SalesQuery: this stays a plain, testable data class and
/// the page/widgets stay about layout.
///
/// Branch is deliberately NOT filtered here. The Owner's AppBar branch
/// selector (BranchScope) already scopes the whole screen — see
/// SettingsPage — so a second, local branch dropdown would just be two
/// controls doing the same job and could disagree with each other.
class UserQuery {
  final String search;
  final String? role; // null = All Roles
  final String? status; // null = All Status
  final UserSort sort;

  const UserQuery({
    this.search = '',
    this.role,
    this.status,
    this.sort = UserSort.recentlyAdded,
  });

  UserQuery copyWith({
    String? search,
    Object? role = _sentinel,
    Object? status = _sentinel,
    UserSort? sort,
  }) {
    return UserQuery(
      search: search ?? this.search,
      role: identical(role, _sentinel) ? this.role : role as String?,
      status: identical(status, _sentinel) ? this.status : status as String?,
      sort: sort ?? this.sort,
    );
  }

  static const _sentinel = Object();

  bool get hasActiveFilters =>
      search.isNotEmpty || role != null || status != null || sort != UserSort.recentlyAdded;

  /// Runs client-side, same rationale as SalesQuery.apply: Firestore can't
  /// do substring search, and this dataset (a shop's staff roster) is small
  /// enough that this never needs to become a real search index.
  List<UserModel> apply(List<UserModel> input) {
    final q = search.trim().toLowerCase();

    var out = input.where((u) {
      if (role != null && u.displayRole.toLowerCase() != role!.toLowerCase()) {
        return false;
      }
      if (status != null && u.status.toLowerCase() != status!.toLowerCase()) {
        return false;
      }
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.displayRole.toLowerCase().contains(q) ||
          u.branch.toLowerCase().contains(q);
    }).toList();

    out.sort((a, b) => switch (sort) {
          UserSort.name => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
          UserSort.recentlyAdded => b.createdAt.compareTo(a.createdAt),
          UserSort.oldest => a.createdAt.compareTo(b.createdAt),
          UserSort.role => a.displayRole.toLowerCase().compareTo(b.displayRole.toLowerCase()),
        });

    return out;
  }
}