import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// M4 权限语法验证脚本（含 code 断言，避免 HTTP 200 + code!=200 假阳性）：
///   IOTDB_PASSWORD=xxx dart run tool/verify_m4.dart [baseUrl]
/// 临时用户/角色 m4_test_*（验证后清理）
Future<void> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args.first : 'http://106.55.231.32:18080';
  final password = Platform.environment['IOTDB_PASSWORD'];
  if (password == null || password.isEmpty) {
    stderr.writeln('请设置 IOTDB_PASSWORD 环境变量');
    exit(1);
  }
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      options.headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode('root:$password'))}';
      handler.next(options);
    },
  ));

  int passed = 0;
  Future<void> check(String name, String sql, {bool write = false}) async {
    final body = await dio.post('/rest/v2/${write ? 'nonQuery' : 'query'}',
        data: {'sql': sql});
    final m = body.data as Map<String, dynamic>;
    final code = m['code'];
    final ok = code == null || code == 200;
    if (!ok) {
      stderr.writeln('  FAIL  $name -> $sql');
      stderr.writeln('        ${m['code']} ${m['message']}');
      exit(1);
    }
    stderr.writeln('  PASS  $name');
    if (!write && ok) {
      final cols = (m['column_names'] as List?)?.join(', ') ?? '';
      final values = m['values'] as List?;
      final rows = values?.isEmpty == true ? 0 : ((values?.firstOrNull as List?)?.length ?? 0);
      if (cols.isNotEmpty) stderr.writeln('        列: $cols 行数: $rows');
    }
    passed++;
  }

  const u = 'm4_test_user';
  const r = 'm4_test_role';
  final db = 'root.desktop_m4';
  stderr.writeln('== M4 语法验证 [$baseUrl] ==');

  stderr.writeln('[1] 用户/角色查询');
  await check('LIST USER', 'LIST USER');
  await check('LIST ROLE', 'LIST ROLE');
  await check('LIST PRIVILEGES OF USER root', 'LIST PRIVILEGES OF USER root');

  stderr.writeln('[2] 用户 CRUD');
  await check('CREATE USER $u', "CREATE USER $u 'm4Pass123!'", write: true);
  await check('LIST USER 后确认', 'LIST USER');
  await check('ALTER USER SET PASSWORD', "ALTER USER $u SET PASSWORD 'm4Pass456!'", write: true);

  stderr.writeln('[3] 角色 CRUD');
  await check('CREATE ROLE $r', 'CREATE ROLE $r', write: true);
  await check('GRANT ROLE TO USER', 'GRANT ROLE $r TO $u', write: true);
  await check('LIST PRIVILEGES OF ROLE $r', 'LIST PRIVILEGES OF ROLE $r');

  stderr.writeln('[4] 授权/撤销（2.0.10 实测语法：全局=SYSTEM ON root.**）');
  await check('GRANT 全局 SYSTEM', 'GRANT SYSTEM ON root.** TO USER $u', write: true);
  await check('GRANT 全局 + WITH GRANT OPTION',
      'GRANT SYSTEM ON root.** TO USER $u WITH GRANT OPTION', write: true);
  await check('GRANT 路径权限',
      "GRANT READ_DATA, WRITE_SCHEMA ON $db.** TO USER $u", write: true);
  await check('GRANT ALL ON root.** TO USER', 'GRANT ALL ON root.** TO USER $u', write: true);
  await check('GRANT 路径权限 TO ROLE',
      "GRANT READ_DATA ON $db.** TO ROLE $r", write: true);
  await check('LIST PRIVILEGES OF USER $u（验证授权）', 'LIST PRIVILEGES OF USER $u');
  await check('LIST PRIVILEGES OF ROLE $r（验证授权）', 'LIST PRIVILEGES OF ROLE $r');
  await check('REVOKE 路径权限', "REVOKE WRITE_SCHEMA ON $db.** FROM USER $u", write: true);
  await check('REVOKE 全局权限', 'REVOKE SYSTEM ON root.** FROM USER $u', write: true);
  await check('REVOKE ALL ON root.** FROM USER', 'REVOKE ALL ON root.** FROM USER $u', write: true);
  await check('REVOKE 路径权限 FROM ROLE', "REVOKE READ_DATA ON $db.** FROM ROLE $r", write: true);
  await check('REVOKE ROLE FROM USER', 'REVOKE ROLE $r FROM $u', write: true);
  await check('LIST PRIVILEGES OF USER $u（撤销后）', 'LIST PRIVILEGES OF USER $u');

  stderr.writeln('[5] 清理');
  await check('DROP ROLE $r', 'DROP ROLE $r', write: true);
  await check('DROP USER $u', 'DROP USER $u', write: true);
  await check('LIST USER 确认清理', 'LIST USER');

  stderr.writeln('\n全部通过 ($passed 项)');
}
