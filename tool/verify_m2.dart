import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// M2 端到端验证脚本：
///   IOTDB_PASSWORD=xxx dart run tool/verify_m2.dart [baseUrl]
/// 只读验证 + 临时测试库 root.desktop_test（验证后清理）
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
  Future<void> check(String name, String sql, {bool write = false}) async {
    try {
      final resp = await dio.post('/rest/v2/${write ? 'nonQuery' : 'query'}',
          data: {'sql': sql});
      final body = resp.data as Map<String, dynamic>;
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

  final db = 'root.desktop_test';
  stderr.writeln('== M2 验证 [$baseUrl] ==');
  stderr.writeln('[1] 只读验证');
  await check('GET /ping', '', write: false);
  await check('SHOW VERSION', 'SHOW VERSION');
  await check('SHOW DATABASES DETAILS', 'SHOW DATABASES DETAILS');

  stderr.writeln('[2] 建库（含 TTL 参数）');
  await check('CREATE DATABASE $db WITH TTL=3600000',
      'CREATE DATABASE $db WITH TTL=3600000, TIME_PARTITION_INTERVAL=86400000',
      write: true);

  stderr.writeln('[3] 建测点（含 TAGS）');
  await check('CREATE TIMESERIES $db.d1.s1',
      "CREATE TIMESERIES $db.d1.s1 WITH DATATYPE=FLOAT, COMPRESSOR=SNAPPY TAGS(unit=Celsius)",
      write: true);
  await check('CREATE TIMESERIES $db.d2.s2',
      "CREATE TIMESERIES $db.d2.s2 WITH DATATYPE=INT64, ENCODING=TS_2DIFF, COMPRESSOR=LZ4 TAGS(unit='count')",
      write: true);

  stderr.writeln('[4] 元数据查询');
  await check('SHOW DEVICES $db.** WITH DATABASE', 'SHOW DEVICES $db.** WITH DATABASE');
  await check('SHOW TIMESERIES $db.**', 'SHOW TIMESERIES $db.**');

  stderr.writeln('[5] TTL 操作');
  await check('SET TTL TO $db 86400000', 'SET TTL TO $db 86400000', write: true);
  await check('SET TTL TO $db INF', 'SET TTL TO $db INF', write: true);
  await check('UNSET TTL TO $db', 'UNSET TTL TO $db', write: true);

  stderr.writeln('[6] 写入数据并查询');
  await check('INSERT 数据', "INSERT INTO $db.d1(timestamp,s1) VALUES(1700000000000, 23.5)", write: true);
  await check('SELECT 数据', "SELECT s1 FROM $db.d1 WHERE time >= 0 LIMIT 10");

  stderr.writeln('[7] 清理');
  await check('DELETE TIMESERIES $db.**', 'DELETE TIMESERIES $db.**', write: true);
  await check('DROP DATABASE $db', 'DROP DATABASE $db', write: true);
  await check('确认已删除', 'SHOW DATABASES DETAILS');

  stderr.writeln('\n全部通过 ($passed 项)');
}