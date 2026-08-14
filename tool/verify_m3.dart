import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// M3 验证脚本（SQL 工作台链路 + M4 权限语法探路）：
///   IOTDB_PASSWORD=xxx dart run tool/verify_m3.dart [baseUrl]
/// 只读验证 + 临时测试库 root.desktop_m3（验证后清理）
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
  Future<Map<String, dynamic>> run(String sql, {bool write = false}) async {
    final resp = await dio.post('/rest/v2/${write ? 'nonQuery' : 'query'}',
        data: {'sql': sql});
    return resp.data as Map<String, dynamic>;
  }

  Future<void> check(String name, String sql, {bool write = false}) async {
    try {
      final body = await run(sql, write: write);
      final code = body['code'];
      if (code is num && code != 200) {
        stderr.writeln('  FAIL  $name -> ${body['message']}');
        exit(1);
      }
      stderr.writeln('  PASS  $name');
      if (!write) {
        final cols = (body['column_names'] as List?)?.join(', ') ??
            (body['expressions'] as List?)?.join(', ') ??
            '';
        final timestamps = body['timestamps'] as List?;
        final rows = timestamps?.length ??
            ((body['values'] as List?)?.firstOrNull as List?)?.length ??
            0;
        stderr.writeln('        列: $cols');
        stderr.writeln('        行数: $rows');
      }
      passed++;
    } catch (e) {
      stderr.writeln('  FAIL  $name -> $e');
      exit(1);
    }
  }

  final db = 'root.desktop_m3';
  stderr.writeln('== M3 验证 [$baseUrl] ==');

  stderr.writeln('[1] 工作台链路（query/nonQuery 路由）');
  await check('SHOW VERSION', 'SHOW VERSION');
  await check('SHOW DATABASES DETAILS', 'SHOW DATABASES DETAILS');
  await check('SHOW TIMESERIES root LIMIT 5', 'SHOW TIMESERIES root LIMIT 5');

  stderr.writeln('[2] 建临时库并写入');
  await check('CREATE DATABASE $db',
      'CREATE DATABASE $db WITH TIME_PARTITION_INTERVAL=86400000', write: true);
  await check('CREATE TIMESERIES $db.d1.s1',
      'CREATE TIMESERIES $db.d1.s1 WITH DATATYPE=FLOAT, COMPRESSOR=SNAPPY',
      write: true);
  await check('INSERT 两行', "INSERT INTO $db.d1(timestamp,s1) VALUES(1700000000000,1.5),(1700000001000,2.5)",
      write: true);
  await check('SELECT 数据（expressions 列名）',
      'SELECT s1 FROM $db.d1 WHERE time >= 0 LIMIT 10');
  await check('SELECT 聚合 GROUP BY', 'SELECT count(s1) FROM $db.d1 GROUP BY(1000ms)');
  await check('SHOW DEVICES $db.** WITH DATABASE', 'SHOW DEVICES $db.** WITH DATABASE');
  await check('SHOW TIMESERIES $db.**', 'SHOW TIMESERIES $db.**');

  stderr.writeln('[3] 多语句拆分模拟（; 分段执行）');
  final multi = 'SHOW VERSION; SELECT 1;';
  for (final s in multi.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty)) {
    await check('多语句: $s', s);
  }

  stderr.writeln('[4] M4 权限语法（只读）');
  await check('LIST USER', 'LIST USER');
  await check('LIST ROLE', 'LIST ROLE');
  await check('LIST PRIVILEGES OF USER root', 'LIST PRIVILEGES OF USER root');

  stderr.writeln('[5] M4 写操作探路（临时用户/角色，验证后清理）');
  final u = 'm3_test_user';
  final r = 'm3_test_role';
  await check('CREATE USER $u', "CREATE USER $u 'm3Pass123!'", write: true);
  await check('ALTER USER SET PASSWORD', "ALTER USER $u SET PASSWORD 'm3Pass456!'", write: true);
  await check('CREATE ROLE $r', 'CREATE ROLE $r', write: true);
  await check('GRANT ROLE TO USER', 'GRANT ROLE $r TO $u', write: true);
  await check('GRANT 全局权限', 'GRANT SYSTEM ON root.** TO USER $u', write: true);
  await check('GRANT 路径权限',
      "GRANT READ_DATA, WRITE_SCHEMA ON $db.** TO USER $u", write: true);
  await check('LIST PRIVILEGES 验证授权', 'LIST PRIVILEGES OF USER $u');
  await check('REVOKE 路径权限', "REVOKE WRITE_SCHEMA ON $db.** FROM USER $u", write: true);
  await check('REVOKE 角色', 'REVOKE ROLE $r FROM $u', write: true);
  await check('DROP ROLE $r', 'DROP ROLE $r', write: true);
  await check('DROP USER $u', 'DROP USER $u', write: true);

  stderr.writeln('[6] 清理');
  await check('DELETE TIMESERIES $db.**', 'DELETE TIMESERIES $db.**', write: true);
  await check('DROP DATABASE $db', 'DROP DATABASE $db', write: true);

  stderr.writeln('\n全部通过 ($passed 项)');
}
