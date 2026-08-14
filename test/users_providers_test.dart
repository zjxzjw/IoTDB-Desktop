import 'package:flutter_test/flutter_test.dart';

import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/features/users/data/users_providers.dart';

void main() {
  group('权限 SQL 生成（2.0.10 实测语法）', () {
    test('全局权限授权固定 root.**', () {
      final sql = grantPrivilegesSql(
        PrivilegeKind.user,
        'alice',
        ['SYSTEM'],
        Privileges.rootScope,
      );
      expect(sql, 'GRANT SYSTEM ON root.** TO USER alice');
    });

    test('路径权限授权 + GRANT OPTION', () {
      final sql = grantPrivilegesSql(
        PrivilegeKind.user,
        'alice',
        ['READ_DATA', 'WRITE_SCHEMA'],
        'root.test.**',
        grantOption: true,
      );
      expect(sql, 'GRANT READ_DATA, WRITE_SCHEMA ON root.test.** TO USER alice WITH GRANT OPTION');
    });

    test('角色授权', () {
      final sql = grantPrivilegesSql(
        PrivilegeKind.role,
        'readonly',
        ['READ_DATA'],
        'root.**',
      );
      expect(sql, 'GRANT READ_DATA ON root.** TO ROLE readonly');
    });

    test('撤销：全局权限映射 root.**', () {
      final sql = revokePrivilegeSql(PrivilegeKind.user, 'alice', 'SYSTEM', '');
      expect(sql, 'REVOKE SYSTEM ON root.** FROM USER alice');
    });

    test('撤销：路径权限原样', () {
      final sql = revokePrivilegeSql(PrivilegeKind.role, 'readonly', 'READ_DATA', 'root.test.**');
      expect(sql, 'REVOKE READ_DATA ON root.test.** FROM ROLE readonly');
    });
  });

  group('LIST PRIVILEGES 解析', () {
    test('列主序响应解析为行主序条目', () {
      final r = QueryResult.fromRestJson({
        'column_names': ['Role', 'Scope', 'Privileges', 'GrantOption'],
        'values': [
          ['', ''],
          ['', 'root.a.b.**'],
          ['SYSTEM', 'READ_DATA'],
          [false, false],
        ],
      }, 1);
      final entries = parsePrivileges(r);
      expect(entries.length, 2);
      expect(entries[0].privilege, 'SYSTEM');
      expect(entries[0].isGlobal, isTrue);
      expect(entries[0].fromRole, isFalse);
      expect(entries[1].scope, 'root.a.b.**');
      expect(entries[1].isGlobal, isFalse);
    });

    test('来自角色的权限标记', () {
      final r = QueryResult.fromRestJson({
        'column_names': ['Role', 'Scope', 'Privileges', 'GrantOption'],
        'values': [
          ['readonly'],
          ['root.**'],
          ['READ_DATA'],
          [false],
        ],
      }, 1);
      final entries = parsePrivileges(r);
      expect(entries.single.role, 'readonly');
      expect(entries.single.fromRole, isTrue);
    });
  });
}
