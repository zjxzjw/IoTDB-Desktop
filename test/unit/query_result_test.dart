import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';

void main() {
  group('fromRestJson（表模型 REST 响应格式）', () {
    test('column_names + values（行主序）', () {
      final json = {
        'column_names': ['TableName', 'TTL(ms)'],
        'data_types': ['TEXT', 'TEXT'],
        'values': [
          ['t1', 'INF'],
          ['t2', '3600'],
        ],
      };
      final r = QueryResult.fromRestJson(json, 12);
      expect(r.columnNames, ['TableName', 'TTL(ms)']);
      expect(r.dataTypes, ['TEXT', 'TEXT']);
      expect(r.rows.length, 2);
      expect(r.rows[0], ['t1', 'INF']);
      expect(r.rows[1], ['t2', '3600']);
      expect(r.elapsedMs, 12);
    });

    test('数据查询：time 为普通列，values 行主序', () {
      final json = {
        'column_names': ['time', 'device_id', 'temperature'],
        'data_types': ['TIMESTAMP', 'STRING', 'FLOAT'],
        'values': [
          [1000, 'WT-001', 21.5],
          [2000, 'WT-001', null],
        ],
      };
      final r = QueryResult.fromRestJson(json, 5);
      expect(r.columnNames, ['time', 'device_id', 'temperature']);
      expect(r.rows.length, 2);
      expect(r.rows[0], [1000, 'WT-001', 21.5]);
      expect(r.rows[1], [2000, 'WT-001', null]);
    });

    test('expressions + timestamps（数据查询）自动补 Time 列', () {
      final json = {
        'expressions': ['temperature', 'humidity'],
        'timestamps': [100, 200, 300],
        'values': [
          [1.0, 2.0, null],
          [3.0, null, 4.0],
        ],
      };
      final r = QueryResult.fromRestJson(json, 5);
      expect(r.columnNames, ['Time', 'temperature', 'humidity']);
      expect(r.rows.length, 3);
      expect(r.rows[0], [100, 1.0, 3.0]);
      expect(r.rows[1], [200, 2.0, null]);
      expect(r.rows[2], [300, null, 4.0]);
    });

    test('columns 兜底（行主序）', () {
      final json = {
        'columns': ['a', 'b'],
        'values': [
          [1, 2],
          [3, 4],
        ],
      };
      final r = QueryResult.fromRestJson(json, 0);
      expect(r.columnNames, ['a', 'b']);
      expect(r.rows, [
        [1, 2],
        [3, 4],
      ]);
    });

    test('rows 键兜底（按行主序解析）', () {
      final json = {
        'column_names': ['x'],
        'rows': [
          [10],
          [20],
          [30],
        ],
      };
      final r = QueryResult.fromRestJson(json, 0);
      expect(r.rows.length, 3);
      expect(r.rows[0], [10]);
      expect(r.rows[2], [30]);
    });

    test('空结果', () {
      final r = QueryResult.fromRestJson(
        {'column_names': [], 'values': [], 'data_types': []},
        0,
      );
      expect(r.rows, isEmpty);
      expect(r.columnNames, isEmpty);
    });

    test('缺列时列名兜底为空数组', () {
      final r = QueryResult.fromRestJson(
        {'values': [[1]]},
        0,
      );
      expect(r.columnNames, isEmpty);
      expect(r.rows, [
        [1],
      ]);
    });
  });

  test('rowCount / columnCount', () {
    final r = QueryResult(
      columnNames: const ['a', 'b'],
      rows: const [
        [1, 2],
      ],
      dataTypes: const [],
      elapsedMs: 0,
    );
    expect(r.rowCount, 1);
    expect(r.columnCount, 2);
  });
}
