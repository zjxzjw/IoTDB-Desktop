import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/table_meta.dart';
import 'package:iotdb_desktop/core/network/iotdb_client.dart';
import 'package:iotdb_desktop/core/utils/sql_builder.dart';

import '../helpers/test_connection.dart';

/// 集成测试：直连真实 IoTDB 表模型 REST 端点（/rest/table/v1/*）。
///
/// 通过环境变量或 --dart-define 传入连接参数，例如：
///   IOTDB_HOST=106.55.231.32 IOTDB_PORT=18080 flutter test test/integration
/// 或
///   flutter test test/integration \
///     --dart-define=IOTDB_HOST=106.55.231.32 \
///     --dart-define=IOTDB_PORT=18080 \
///     --dart-define=IOTDB_USER=root \
///     --dart-define=IOTDB_PASSWORD=root
///
/// 注意：本测试【不清理】创建的对象，便于在工具中查看数据
/// （库 demo、表 wind_turbine 及示例数据会保留）。
final String host = Platform.environment['IOTDB_HOST'] ??
    const String.fromEnvironment('IOTDB_HOST', defaultValue: '');
final int port = int.tryParse(
      Platform.environment['IOTDB_PORT'] ??
          const String.fromEnvironment('IOTDB_PORT', defaultValue: ''),
    ) ??
    18080;
final String user = Platform.environment['IOTDB_USER'] ??
    const String.fromEnvironment('IOTDB_USER', defaultValue: 'root');
final String password = Platform.environment['IOTDB_PASSWORD'] ??
    const String.fromEnvironment('IOTDB_PASSWORD', defaultValue: 'root');

const String db = 'demo';
const String table = 'wind_turbine';

IotdbClient client() => IotdbClient(
  testConnection(
    id: 'integration',
    name: 'Integration',
    host: host,
    port: port,
    username: user,
    password: password,
  ),
);

int nowMs() => DateTime.now().millisecondsSinceEpoch;

void main() {
  final enabled = host.isNotEmpty;

  group('连接与模型', () {
    test('ping 与版本', () async {
      final c = client();
      final ms = await c.ping();
      expect(ms, greaterThanOrEqualTo(0));
      final r = await c.query('SHOW VERSION');
      expect(r.rows.first.first.toString(), contains('2.0.10'));
    }, skip: !enabled);

    test('表模型方言生效', () async {
      final r = await client().query('SHOW CURRENT_SQL_DIALECT');
      expect(r.rows.first.first.toString().toUpperCase(), 'TABLE');
    }, skip: !enabled);
  });

  group('数据库管理', () {
    test('建库（幂等）', () async {
      final c = client();
      await c.nonQuery('CREATE DATABASE IF NOT EXISTS ${SqlBuilder.ident(db)}');
      final r = await c.query('SHOW DATABASES');
      expect(
        r.rows.any((row) => row.isNotEmpty && '${row.first}' == db),
        isTrue,
        reason: 'SHOW DATABASES 应包含 $db',
      );
    }, skip: !enabled);

    test('SHOW DATABASES DETAILS 可解析', () async {
      final r = await client().query('SHOW DATABASES DETAILS');
      expect(r.columnNames.map((n) => n.toLowerCase()), contains('database'));
      expect(r.columnNames.map((n) => n.toLowerCase()), contains('ttl(ms)'));
    }, skip: !enabled);

    test('ALTER DATABASE 设置 TTL', () async {
      final c = client();
      await c.nonQuery(
        SqlBuilder.alterDatabaseTtl(db, ttlMs: 31536000000),
      );
      final r = await c.query('SHOW DATABASES DETAILS');
      expect(
        r.rows.any((row) => '${row.first}' == db),
        isTrue,
      );
    }, skip: !enabled);
  });

  group('表管理', () {
    test('建表（TIME/TAG/ATTRIBUTE/FIELD）', () async {
      final c = client();
      final cols = [
        TableColumn(
          name: 'time',
          dataType: 'TIMESTAMP',
          category: ColumnCategory.time,
        ),
        TableColumn(
          name: 'region',
          dataType: 'STRING',
          category: ColumnCategory.tag,
        ),
        TableColumn(
          name: 'plant_id',
          dataType: 'STRING',
          category: ColumnCategory.tag,
        ),
        TableColumn(
          name: 'device_id',
          dataType: 'STRING',
          category: ColumnCategory.tag,
        ),
        TableColumn(
          name: 'model',
          dataType: 'STRING',
          category: ColumnCategory.attribute,
        ),
        TableColumn(
          name: 'temperature',
          dataType: 'FLOAT',
          category: ColumnCategory.field,
          comment: '温度',
        ),
        TableColumn(
          name: 'humidity',
          dataType: 'DOUBLE',
          category: ColumnCategory.field,
          comment: '湿度',
        ),
        TableColumn(
          name: 'status',
          dataType: 'BOOLEAN',
          category: ColumnCategory.field,
        ),
      ];
      await c.nonQuery(
        SqlBuilder.createTable(
          db,
          table,
          columns: cols,
          comment: '风机表',
          ifNotExists: true,
        ),
      );
      final r = await c.query('SHOW TABLES DETAILS FROM ${SqlBuilder.ident(db)}');
      final tables = parseTables(r, db);
      expect(tables.any((t) => t.name == table), isTrue);
      final created = tables.firstWhere((t) => t.name == table);
      expect(created.status?.toUpperCase(), 'USING');
    }, skip: !enabled);

    test('DESC 解析列结构', () async {
      final r = await client().query(
        'DESC ${SqlBuilder.qualified(db, table)} DETAILS',
      );
      final cols = parseColumns(r);
      expect(cols.any((c) => c.name == 'time' && c.category == ColumnCategory.time), isTrue);
      expect(cols.any((c) => c.name == 'device_id' && c.category == ColumnCategory.tag), isTrue);
      expect(cols.any((c) => c.name == 'model' && c.category == ColumnCategory.attribute), isTrue);
      expect(cols.any((c) => c.name == 'temperature' && c.category == ColumnCategory.field), isTrue);
    }, skip: !enabled);

    test('ALTER 加列/删列', () async {
      final c = client();
      final col = TableColumn(
        name: 'note',
        dataType: 'STRING',
        category: ColumnCategory.attribute,
      );
      await c.nonQuery(SqlBuilder.alterAddColumn(db, table, col));

      var r = await c.query('DESC ${SqlBuilder.qualified(db, table)} DETAILS');
      expect(parseColumns(r).any((x) => x.name == 'note'), isTrue);

      await c.nonQuery(SqlBuilder.alterDropColumn(db, table, 'note'));
      r = await c.query('DESC ${SqlBuilder.qualified(db, table)} DETAILS');
      expect(parseColumns(r).any((x) => x.name == 'note'), isFalse);
    }, skip: !enabled);

    test('ALTER TABLE 设置表 TTL', () async {
      final c = client();
      await c.nonQuery(SqlBuilder.alterTableTtl(db, table, ttlMs: 31536000000));
      final r = await c.query('SHOW TABLES DETAILS FROM ${SqlBuilder.ident(db)}');
      final t = parseTables(r, db).firstWhere((x) => x.name == table);
      expect(t.ttl, isNotNull);
    }, skip: !enabled);
  });

  group('数据管理', () {
    test('写入示例数据', () async {
      final c = client();
      final base = nowMs() - const Duration(hours: 2).inMilliseconds;
      final values = <String>[];
      final rand = Random(42);
      for (var i = 0; i < 24; i++) {
        final ts = base + i * 60000; // 每分钟一个点，共 24 分钟
        final temp = (20 + rand.nextDouble() * 10).toStringAsFixed(1);
        final hum = (50 + rand.nextDouble() * 20).toStringAsFixed(1);
        final status = i.isEven;
        values.add(
          "($ts, '华东', 'P001', 'WT-001', 'M1', $temp, $hum, $status)",
        );
      }
      final sql =
          'INSERT INTO ${SqlBuilder.qualified(db, table)} '
          '(time, region, plant_id, device_id, model, temperature, humidity, status) '
          'VALUES ${values.join(', ')}';
      await c.nonQuery(sql);
    }, skip: !enabled);

    test('原始数据查询（时间过滤 + 分页）', () async {
      final c = client();
      final end = nowMs();
      final start = end - const Duration(hours: 3).inMilliseconds;
      final r = await c.query(
        'SELECT time, device_id, temperature, humidity '
        'FROM ${SqlBuilder.qualified(db, table)} '
        'WHERE time >= $start AND time <= $end '
        'LIMIT 100 OFFSET 0',
      );
      expect(r.rows, isNotEmpty);
      expect(r.columnNames.map((n) => n.toLowerCase()), contains('time'));
    }, skip: !enabled);

    test('count(*) 统计', () async {
      final r = await client().query(
        'SELECT count(*) FROM ${SqlBuilder.qualified(db, table)}',
      );
      final n = int.tryParse('${r.rows.first.first}') ?? 0;
      expect(n, greaterThan(0));
    }, skip: !enabled);

    test('TAG 过滤', () async {
      final r = await client().query(
        'SELECT * FROM ${SqlBuilder.qualified(db, table)} '
        "WHERE device_id = 'WT-001' LIMIT 10",
      );
      expect(r.rows, isNotEmpty);
    }, skip: !enabled);

    test('图表聚合（date_bin_gapfill + GROUP BY 1）', () async {
      final c = client();
      final end = nowMs();
      final start = end - const Duration(hours: 3).inMilliseconds;
      final sql =
          'SELECT date_bin_gapfill(5m, time) AS time, '
          'avg(temperature) AS temperature, avg(humidity) AS humidity '
          'FROM ${SqlBuilder.qualified(db, table)} '
          'WHERE time >= $start AND time <= $end '
          'GROUP BY 1 FILL METHOD PREVIOUS';
      final r = await c.query(sql);
      expect(r.rows, isNotEmpty, reason: '聚合结果应有数据');
      // 聚合列存在
      final names = r.columnNames.map((n) => n.toLowerCase()).toSet();
      expect(names.contains('time'), isTrue);
    }, skip: !enabled);
  });
}
