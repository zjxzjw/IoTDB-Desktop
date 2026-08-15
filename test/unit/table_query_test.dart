import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/features/data/data/data_providers.dart';

void main() {
  TableQuery query({
    List<String> columns = const ['temperature', 'humidity'],
    Map<String, String> aggs = const {'temperature': 'avg', 'humidity': 'avg'},
    Map<String, String> tags = const {},
    int startMs = 100,
    int endMs = 200,
    String interval = '5m',
    int page = 0,
  }) {
    return TableQuery(
      db: 'demo',
      table: 't1',
      columns: columns,
      columnAggs: aggs,
      tagFilters: tags,
      startMs: startMs,
      endMs: endMs,
      interval: interval,
      page: page,
      pageSize: 100,
    );
  }

  group('displayColumns', () {
    test('time 在前并去重（大小写不敏感）', () {
      final q = query(columns: ['time', 'temperature', 'Time']);
      expect(q.displayColumns, ['time', 'temperature']);
    });

    test('常规选择', () {
      final q = query(columns: ['temperature', 'humidity']);
      expect(q.displayColumns, ['time', 'temperature', 'humidity']);
    });
  });

  group('rawSql', () {
    test('基本查询（时间窗 + 分页）', () {
      expect(
        query().rawSql,
        'SELECT "time", "temperature", "humidity" FROM "demo"."t1" '
        'WHERE time >= 100 AND time <= 200 LIMIT 100 OFFSET 0',
      );
    });

    test('分页 OFFSET', () {
      expect(
        query(page: 2).rawSql,
        'SELECT "time", "temperature", "humidity" FROM "demo"."t1" '
        'WHERE time >= 100 AND time <= 200 LIMIT 100 OFFSET 200',
      );
    });

    test('TAG 过滤进入 WHERE 并转义单引号', () {
      final q = query(tags: {'region': "北'京"});
      expect(
        q.rawSql,
        'SELECT "time", "temperature", "humidity" FROM "demo"."t1" '
        'WHERE time >= 100 AND time <= 200 AND "region" = \'北\'\'京\' '
        'LIMIT 100 OFFSET 0',
      );
    });

    test('空值 TAG 过滤被忽略', () {
      final q = query(tags: {'region': '   '});
      expect(q.rawSql, contains('WHERE time >= 100 AND time <= 200 LIMIT'));
      expect(q.rawSql, isNot(contains('region')));
    });
  });

  group('countSql', () {
    test('count(*) + 时间窗', () {
      expect(
        query().countSql,
        'SELECT count(*) FROM "demo"."t1" WHERE time >= 100 AND time <= 200',
      );
    });
  });

  group('chartSql', () {
    test('date_bin_gapfill + GROUP BY 1 + FILL', () {
      final sql = query(interval: '5m').chartSql;
      expect(
        sql,
        'SELECT date_bin_gapfill(5m, time) AS time, '
        'avg("temperature") AS "temperature", avg("humidity") AS "humidity" '
        'FROM "demo"."t1" WHERE time >= 100 AND time <= 200 '
        'GROUP BY 1 FILL METHOD PREVIOUS',
      );
    });

    test('缺省聚合使用 avg 兜底', () {
      final q = TableQuery(
        db: 'demo',
        table: 't1',
        columns: ['x'],
        columnAggs: const {},
        startMs: 1,
        endMs: 2,
        interval: '1m',
      );
      expect(q.chartSql, contains('avg("x") AS "x"'));
    });
  });

  group('aggregateFor', () {
    test('数值类型 avg，其余 count', () {
      expect(aggregateFor('FLOAT'), 'avg');
      expect(aggregateFor('DOUBLE'), 'avg');
      expect(aggregateFor('int64'), 'avg');
      expect(aggregateFor('STRING'), 'count');
      expect(aggregateFor('BOOLEAN'), 'count');
      expect(aggregateFor(''), 'count');
    });
  });

  group('TimeRange', () {
    test('标签与时长', () {
      expect(TimeRange.h1.label, '最近 1 小时');
      expect(TimeRange.h24.label, '最近 24 小时');
      expect(TimeRange.d30.label, '最近 30 天');
      expect(TimeRange.d7.duration.inDays, 7);
      expect(TimeRange.h6.duration.inHours, 6);
    });

    test('默认聚合窗口', () {
      expect(TimeRange.h1.defaultInterval, '10000ms');
      expect(TimeRange.h24.defaultInterval, '5m');
      expect(TimeRange.d7.defaultInterval, '1h');
      expect(TimeRange.d30.defaultInterval, '1d');
    });
  });

  test('intervalOptions', () {
    expect(intervalOptions, ['auto', '10s', '1m', '5m', '1h', '1d']);
  });

  test('copyWith 仅改页码', () {
    final q = query(page: 1);
    final p2 = q.copyWith(page: 3);
    expect(p2.page, 3);
    expect(p2.pageSize, 100);
    expect(p2.db, 'demo');
    expect(p2.table, 't1');
    expect(p2.interval, '5m');
    expect(p2.columns, ['temperature', 'humidity']);
  });
}
