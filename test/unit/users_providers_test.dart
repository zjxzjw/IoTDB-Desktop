import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/features/users/data/users_providers.dart';

QueryResult result({
  List<String> columns = const [],
  List<List<dynamic>> rows = const [],
}) {
  return QueryResult(
    columnNames: columns,
    rows: rows,
    dataTypes: const [],
    elapsedMs: 0,
  );
}

void main() {
  group('PrivilegeKind', () {
    test('sqlKeyword / label', () {
      expect(PrivilegeKind.user.sqlKeyword, 'USER');
      expect(PrivilegeKind.user.label, '用户');
      expect(PrivilegeKind.role.sqlKeyword, 'ROLE');
      expect(PrivilegeKind.role.label, '角色');
    });
  });

  group('Privileges', () {
    test('常量集合', () {
      expect(Privileges.global, ['SYSTEM', 'SECURITY']);
      expect(Privileges.path, ['READ_DATA', 'WRITE_DATA', 'READ_SCHEMA', 'WRITE_SCHEMA']);
      expect(Privileges.all, 'ALL');
      expect(Privileges.rootScope, 'root.**');
      expect(Privileges.allGrantable, containsAll(Privileges.allGrantable));
    });

    test('requiresRootScope', () {
      expect(Privileges.requiresRootScope('SYSTEM'), isTrue);
      expect(Privileges.requiresRootScope('ALL'), isTrue);
      expect(Privileges.requiresRootScope('READ_DATA'), isFalse);
    });
  });

  group('grantPrivilegesSql', () {
    test('单权限 + WITH GRANT OPTION', () {
      expect(
        grantPrivilegesSql(PrivilegeKind.user, 'alice', ['READ_DATA'], 'demo', grantOption: true),
        'GRANT READ_DATA ON demo TO USER alice WITH GRANT OPTION',
      );
    });

    test('多权限 + 表作用域', () {
      expect(
        grantPrivilegesSql(PrivilegeKind.role, 'r1', ['READ', 'WRITE'], 'demo.t1'),
        'GRANT READ, WRITE ON demo.t1 TO ROLE r1',
      );
    });
  });

  group('revokePrivilegeSql', () {
    test('指定作用域', () {
      expect(
        revokePrivilegeSql(PrivilegeKind.user, 'alice', 'READ_DATA', 'demo.t1'),
        'REVOKE READ_DATA ON demo.t1 FROM USER alice',
      );
    });

    test('空作用域回退 root.**', () {
      expect(
        revokePrivilegeSql(PrivilegeKind.user, 'alice', 'SYSTEM', ''),
        'REVOKE SYSTEM ON root.** FROM USER alice',
      );
    });
  });

  group('parsePrivileges', () {
    test('完整解析', () {
      final r = result(
        columns: ['Role', 'Scope', 'Privileges', 'GrantOption'],
        rows: [
          ['', 'demo', 'READ_DATA', true],
          ['', '', 'SYSTEM', false],
          ['roleA', 'demo.t1', 'WRITE_DATA', false],
        ],
      );
      final entries = parsePrivileges(r);
      expect(entries.length, 3);
      expect(entries[0].privilege, 'READ_DATA');
      expect(entries[0].scope, 'demo');
      expect(entries[0].grantOption, isTrue);
      expect(entries[0].isGlobal, isFalse);
      expect(entries[1].scope, '');
      expect(entries[1].isGlobal, isTrue);
      expect(entries[2].role, 'roleA');
      expect(entries[2].fromRole, isTrue);
    });

    test('缺 Privileges 列返回空', () {
      final r = result(columns: ['x'], rows: [['y']]);
      expect(parsePrivileges(r), isEmpty);
    });
  });
}
