import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/query_result.dart';
import '../../../core/providers.dart';

/// 权限目标类型：用户或角色
enum PrivilegeKind { user, role }

extension PrivilegeKindX on PrivilegeKind {
  String get sqlKeyword => this == PrivilegeKind.user ? 'USER' : 'ROLE';

  String get label => this == PrivilegeKind.user ? '用户' : '角色';
}

/// 权限查询目标（用户/角色名）
class PrivilegeTarget {
  final PrivilegeKind kind;
  final String name;

  const PrivilegeTarget(this.kind, this.name);
}

/// 一条权限记录（LIST PRIVILEGES OF USER/ROLE x 解析结果）
class PrivilegeEntry {
  /// 非空表示该权限通过此角色授予
  final String role;

  /// 空 = 全局权限（SYSTEM/SECURITY），撤销时映射 root.**
  final String scope;

  final String privilege;
  final bool grantOption;

  const PrivilegeEntry({
    required this.role,
    required this.scope,
    required this.privilege,
    required this.grantOption,
  });

  bool get isGlobal => scope.isEmpty;

  bool get fromRole => role.isNotEmpty;
}

/// 2.0.10 权限常量（树表两模型均可用，作用范围语义不同）：
/// 全局权限仅 SYSTEM/SECURITY（MAINTAIN/USE_UDF 等已废弃，服务器提示改用 SYSTEM），
/// 且只能挂在 root.**；路径权限 4 个；ALL 仅限 root.**
/// 表模型下路径权限作用范围为 数据库名 / 库.表，如 db1、db1.table1。
abstract final class Privileges {
  static const global = ['SYSTEM', 'SECURITY'];

  static const path = ['READ_DATA', 'WRITE_DATA', 'READ_SCHEMA', 'WRITE_SCHEMA'];

  static const all = 'ALL';

  static const rootScope = 'root.**';

  /// 可授予的全部权限（UI 选择顺序）
  static const allGrantable = ['SYSTEM', 'SECURITY', 'READ_DATA', 'WRITE_DATA', 'READ_SCHEMA', 'WRITE_SCHEMA', 'ALL'];

  static bool isGlobal(String privilege) => global.contains(privilege);

  static bool requiresRootScope(String privilege) => isGlobal(privilege) || privilege == all;
}

/// 用户列表：LIST USER（列 UserId, User）
final userListProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('LIST USER');
});

/// 角色列表：LIST ROLE（列 Role）
final roleListProvider = FutureProvider<QueryResult>((ref) {
  return ref.watch(iotdbClientProvider).query('LIST ROLE');
});

/// 权限列表：LIST PRIVILEGES OF USER|ROLE `<name>`
final privilegesProvider = FutureProvider.family<QueryResult, PrivilegeTarget>((ref, target) {
  return ref.watch(iotdbClientProvider).query('LIST PRIVILEGES OF ${target.kind.sqlKeyword} ${target.name}');
});

/// 解析权限查询结果（列 Role, Scope, Privileges, GrantOption）
List<PrivilegeEntry> parsePrivileges(QueryResult r) {
  final iRole = r.columnNames.indexOf('Role');
  final iScope = r.columnNames.indexOf('Scope');
  final iPriv = r.columnNames.indexOf('Privileges');
  final iGrant = r.columnNames.indexOf('GrantOption');
  if (iPriv < 0) return const [];
  return [
    for (final row in r.rows)
      PrivilegeEntry(
        role: iRole >= 0 && row.length > iRole ? '${row[iRole]}' : '',
        scope: iScope >= 0 && row.length > iScope ? '${row[iScope]}' : '',
        privilege: '${row[iPriv]}',
        grantOption: iGrant >= 0 && row.length > iGrant ? row[iGrant] == true : false,
      ),
  ];
}

/// 授权：GRANT `<privs>` ON `<path>` TO USER|ROLE `<name>` [WITH GRANT OPTION]
String grantPrivilegesSql(
  PrivilegeKind kind,
  String name,
  List<String> privileges,
  String scope, {
  bool grantOption = false,
}) {
  final withOpt = grantOption ? ' WITH GRANT OPTION' : '';
  return 'GRANT ${privileges.join(', ')} ON $scope TO ${kind.sqlKeyword} $name$withOpt';
}

/// 撤销单条权限：REVOKE `<priv>` ON `<scope|root.**>` FROM USER|ROLE `<name>`
String revokePrivilegeSql(PrivilegeKind kind, String name, String privilege, String scope) {
  final s = scope.isEmpty ? Privileges.rootScope : scope;
  return 'REVOKE $privilege ON $s FROM ${kind.sqlKeyword} $name';
}
