import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/table_meta.dart';
import 'package:iotdb_desktop/core/utils/sql_builder.dart';

void main() {
  group('ident', () {
    test('普通标识符加双引号', () {
      expect(SqlBuilder.ident('table1'), '"table1"');
    });

    test('含中文/特殊字符', () {
      expect(SqlBuilder.ident('风机表'), '"风机表"');
      expect(SqlBuilder.ident('a.b'), '"a.b"');
    });

    test('双引号转义为双引号', () {
      expect(SqlBuilder.ident('a"b'), '"a""b"');
    });
  });

  group('qualified', () {
    test('库表全限定', () {
      expect(SqlBuilder.qualified('demo', 't1'), '"demo"."t1"');
      expect(SqlBuilder.qualified('风电场', '风机'), '"风电场"."风机"');
    });
  });

  group('columnDef', () {
    test('基本列定义', () {
      final col = TableColumn(
        name: 'temperature',
        dataType: 'FLOAT',
        category: ColumnCategory.field,
      );
      expect(SqlBuilder.columnDef(col), '"temperature" FLOAT FIELD');
    });

    test('TAG/时间列', () {
      final tag = TableColumn(
        name: 'device_id',
        dataType: 'STRING',
        category: ColumnCategory.tag,
      );
      expect(SqlBuilder.columnDef(tag), '"device_id" STRING TAG');
      final time = TableColumn(
        name: 'time',
        dataType: 'TIMESTAMP',
        category: ColumnCategory.time,
      );
      expect(SqlBuilder.columnDef(time), '"time" TIMESTAMP TIME');
    });

    test('带注释', () {
      final col = TableColumn(
        name: 'temp',
        dataType: 'FLOAT',
        category: ColumnCategory.field,
        comment: "temperature",
      );
      expect(
        SqlBuilder.columnDef(col),
        '"temp" FLOAT FIELD COMMENT \'temperature\'',
      );
    });

    test('注释内单引号转义', () {
      final col = TableColumn(
        name: 't',
        dataType: 'FLOAT',
        category: ColumnCategory.field,
        comment: "it's",
      );
      expect(
        SqlBuilder.columnDef(col),
        '"t" FLOAT FIELD COMMENT \'it\'\'s\'',
      );
    });
  });

  group('createDatabase', () {
    test('无参数', () {
      expect(SqlBuilder.createDatabase('demo'), 'CREATE DATABASE "demo"');
    });

    test('带 TTL', () {
      expect(
        SqlBuilder.createDatabase('demo', ttlMs: 604800000),
        'CREATE DATABASE "demo" WITH (TTL=604800000)',
      );
    });

    test('多参数顺序', () {
      expect(
        SqlBuilder.createDatabase(
          'demo',
          ttlMs: 1000,
          timePartitionIntervalMs: 86400000,
          schemaRegionGroupNum: 1,
          dataRegionGroupNum: 2,
        ),
        'CREATE DATABASE "demo" WITH '
        '(TTL=1000, TIME_PARTITION_INTERVAL=86400000, '
        'SCHEMA_REGION_GROUP_NUM=1, DATA_REGION_GROUP_NUM=2)',
      );
    });
  });

  test('dropDatabase', () {
    expect(SqlBuilder.dropDatabase('demo'), 'DROP DATABASE "demo"');
  });

  group('alterDatabaseTtl', () {
    test('自定义毫秒', () {
      expect(
        SqlBuilder.alterDatabaseTtl('demo', ttlMs: 3600),
        'ALTER DATABASE "demo" SET PROPERTIES TTL=3600',
      );
    });

    test('INF', () {
      expect(
        SqlBuilder.alterDatabaseTtl('demo'),
        'ALTER DATABASE "demo" SET PROPERTIES TTL=INF',
      );
    });
  });

  group('createTable', () {
    final timeCol = TableColumn(
      name: 'time',
      dataType: 'TIMESTAMP',
      category: ColumnCategory.time,
    );
    final tagCol = TableColumn(
      name: 'device_id',
      dataType: 'STRING',
      category: ColumnCategory.tag,
    );
    final fieldCol = TableColumn(
      name: 'temperature',
      dataType: 'FLOAT',
      category: ColumnCategory.field,
    );

    test('显式时间列', () {
      final sql = SqlBuilder.createTable(
        'demo',
        't1',
        columns: [timeCol, tagCol, fieldCol],
      );
      expect(
        sql,
        'CREATE TABLE "demo"."t1" '
        '("time" TIMESTAMP TIME, "device_id" STRING TAG, '
        '"temperature" FLOAT FIELD)',
      );
    });

    test('未定义时间列时自动补充', () {
      final sql = SqlBuilder.createTable(
        'demo',
        't1',
        columns: [tagCol, fieldCol],
      );
      expect(sql, startsWith('CREATE TABLE "demo"."t1" ("time" TIMESTAMP TIME'));
      expect(sql, contains('"device_id" STRING TAG'));
      expect(sql, contains('"temperature" FLOAT FIELD'));
    });

    test('无列时仅时间列', () {
      expect(
        SqlBuilder.createTable('demo', 't1', columns: const []),
        'CREATE TABLE "demo"."t1" ("time" TIMESTAMP TIME)',
      );
    });

    test('带注释与 TTL', () {
      final sql = SqlBuilder.createTable(
        'demo',
        't1',
        columns: [fieldCol],
        comment: '风机表',
        ttlMs: 604800000,
      );
      expect(sql, contains("COMMENT '风机表'"));
      expect(sql, endsWith('WITH (TTL=604800000)'));
    });

    test('IF NOT EXISTS', () {
      final sql = SqlBuilder.createTable(
        'demo',
        't1',
        columns: [fieldCol],
        ifNotExists: true,
      );
      expect(
        sql,
        'CREATE TABLE IF NOT EXISTS "demo"."t1" ("time" TIMESTAMP TIME, "temperature" FLOAT FIELD)',
      );
    });
  });

  group('dropTable', () {
    test('默认带 IF EXISTS', () {
      expect(
        SqlBuilder.dropTable('demo', 't1'),
        'DROP TABLE IF EXISTS "demo"."t1"',
      );
    });

    test('不带 IF EXISTS', () {
      expect(
        SqlBuilder.dropTable('demo', 't1', ifExists: false),
        'DROP TABLE "demo"."t1"',
      );
    });
  });

  group('alter 列', () {
    test('add column', () {
      final col = TableColumn(
        name: 'humidity',
        dataType: 'DOUBLE',
        category: ColumnCategory.field,
      );
      expect(
        SqlBuilder.alterAddColumn('demo', 't1', col),
        'ALTER TABLE "demo"."t1" ADD COLUMN IF NOT EXISTS "humidity" DOUBLE FIELD',
      );
    });

    test('drop column', () {
      expect(
        SqlBuilder.alterDropColumn('demo', 't1', 'humidity'),
        'ALTER TABLE "demo"."t1" DROP COLUMN IF EXISTS "humidity"',
      );
    });
  });

  group('alterTableTtl', () {
    test('自定义毫秒', () {
      expect(
        SqlBuilder.alterTableTtl('demo', 't1', ttlMs: 3600),
        'ALTER TABLE "demo"."t1" SET PROPERTIES TTL=3600',
      );
    });

    test('INF', () {
      expect(
        SqlBuilder.alterTableTtl('demo', 't1'),
        'ALTER TABLE "demo"."t1" SET PROPERTIES TTL=INF',
      );
    });

    test('恢复数据库默认', () {
      expect(
        SqlBuilder.alterTableTtl('demo', 't1', useDefault: true),
        'ALTER TABLE "demo"."t1" SET PROPERTIES TTL=default',
      );
    });
  });
}
