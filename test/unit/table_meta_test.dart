import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/core/models/table_meta.dart';

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
  group('ColumnCategory', () {
    test('label / sqlKeyword', () {
      expect(ColumnCategory.time.label, '时间列');
      expect(ColumnCategory.time.sqlKeyword, 'TIME');
      expect(ColumnCategory.tag.label, '标签列');
      expect(ColumnCategory.tag.sqlKeyword, 'TAG');
      expect(ColumnCategory.attribute.label, '属性列');
      expect(ColumnCategory.attribute.sqlKeyword, 'ATTRIBUTE');
      expect(ColumnCategory.field.label, '测点列');
      expect(ColumnCategory.field.sqlKeyword, 'FIELD');
    });
  });

  group('tableDataTypes / isNumericType', () {
    test('数据类型集合包含关键类型', () {
      expect(tableDataTypes, containsAll(['BOOLEAN', 'STRING', 'FLOAT', 'DOUBLE', 'TIMESTAMP']));
    });

    test('数值类型判定（大小写不敏感）', () {
      expect(isNumericType('FLOAT'), isTrue);
      expect(isNumericType('double'), isTrue);
      expect(isNumericType('INT32'), isTrue);
      expect(isNumericType('STRING'), isFalse);
      expect(isNumericType('BOOLEAN'), isFalse);
    });
  });

  group('TableColumn.canDrop', () {
    TableColumn col(ColumnCategory c) => TableColumn(
      name: 'x',
      dataType: 'STRING',
      category: c,
    );

    test('FIELD / ATTRIBUTE 可删，TIME / TAG 不可删', () {
      expect(col(ColumnCategory.field).canDrop, isTrue);
      expect(col(ColumnCategory.attribute).canDrop, isTrue);
      expect(col(ColumnCategory.time).canDrop, isFalse);
      expect(col(ColumnCategory.tag).canDrop, isFalse);
    });
  });

  group('TableRef', () {
    test('相等与哈希', () {
      expect(const TableRef('demo', 't1'), const TableRef('demo', 't1'));
      expect(const TableRef('demo', 't1').hashCode, const TableRef('demo', 't1').hashCode);
      expect(const TableRef('demo', 't1'), isNot(const TableRef('demo', 't2')));
      expect(const TableRef('demo', 't1'), isNot(const TableRef('demo2', 't1')));
    });
  });

  group('parseTables', () {
    test('大小写不敏感列名映射', () {
      final r = result(
        columns: ['TableName', 'TTL(ms)', 'Status', 'Comment'],
        rows: [
          ['t1', 'INF', 'USING', 'comment'],
          ['t2', '3600', 'PRE_CREATE', null],
        ],
      );
      final tables = parseTables(r, 'demo');
      expect(tables.length, 2);
      expect(tables[0].db, 'demo');
      expect(tables[0].name, 't1');
      expect(tables[0].ttl, 'INF');
      expect(tables[0].status, 'USING');
      expect(tables[0].comment, 'comment');
      expect(tables[1].name, 't2');
      expect(tables[1].ttl, '3600');
      expect(tables[1].status, 'PRE_CREATE');
      expect(tables[1].comment, isNull);
    });

    test('列名缺失时 name 回退到第一列', () {
      final r = result(
        columns: ['X'],
        rows: [
          ['t1'],
        ],
      );
      final tables = parseTables(r, 'demo');
      expect(tables.single.name, 't1');
      expect(tables.single.ttl, isNull);
    });
  });

  group('parseColumns', () {
    test('类别映射（大小写不敏感）', () {
      final r = result(
        columns: ['ColumnName', 'DataType', 'Category'],
        rows: [
          ['time', 'TIMESTAMP', 'TIME'],
          ['device_id', 'STRING', 'tag'],
          ['note', 'STRING', 'Attribute'],
          ['temperature', 'FLOAT', 'FIELD'],
          ['unknown', 'DOUBLE', 'WEIRD'],
        ],
      );
      final cols = parseColumns(r);
      expect(cols.length, 5);
      expect(cols[0].category, ColumnCategory.time);
      expect(cols[1].category, ColumnCategory.tag);
      expect(cols[2].category, ColumnCategory.attribute);
      expect(cols[3].category, ColumnCategory.field);
      expect(cols[4].category, ColumnCategory.field, reason: '未知类别按 FIELD 处理');
      expect(cols[0].dataType, 'TIMESTAMP');
      expect(cols[1].dataType, 'STRING');
    });

    test('带 Status / Comment', () {
      final r = result(
        columns: ['ColumnName', 'DataType', 'Category', 'Status', 'Comment'],
        rows: [
          ['temp', 'FLOAT', 'FIELD', 'USING', '温度'],
        ],
      );
      final col = parseColumns(r).single;
      expect(col.status, 'USING');
      expect(col.comment, '温度');
    });
  });
}
