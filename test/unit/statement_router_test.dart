import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/network/statement_router.dart';

void main() {
  group('isQuery → query 接口', () {
    const queries = [
      'SELECT * FROM "demo"."t1"',
      'select temperature from demo.t1',
      'SHOW DATABASES',
      'SHOW TABLES FROM demo',
      'SHOW TABLES DETAILS FROM demo',
      'SHOW CURRENT_SQL_DIALECT',
      'COUNT TABLES',
      'count(*)',
      'LIST USER',
      'LIST PRIVILEGES OF USER root',
      'DESC demo.t1',
      'DESC demo.t1 DETAILS',
      'DESCRIBE demo.t1',
      'EXPLAIN SELECT * FROM t1',
      'LOAD CONFIGURATION',
    ];
    for (final sql in queries) {
      test('「$sql」→ query', () {
        expect(StatementRouter.isQuery(sql), isTrue);
      });
    }
  });

  group('isQuery → nonQuery 接口', () {
    const nonQueries = [
      'CREATE DATABASE demo',
      'CREATE TABLE demo.t1 (time TIMESTAMP TIME)',
      'DROP DATABASE demo',
      'DROP TABLE demo.t1',
      'ALTER TABLE demo.t1 ADD COLUMN IF NOT EXISTS a FLOAT FIELD',
      'ALTER DATABASE demo SET PROPERTIES TTL=1000',
      "INSERT INTO demo.t1 (time, temperature) VALUES (1, 2.0)",
      'USE demo',
      'SET SQL_DIALECT=TABLE',
      'GRANT READ_DATA ON demo TO USER alice',
      'REVOKE READ_DATA ON demo FROM USER alice',
      'COMMENT ON TABLE demo.t1 IS \'x\'',
      'DELETE FROM demo.t1',
      'UNSET',
      '',
      '   ',
    ];
    for (final sql in nonQueries) {
      test('「$sql」→ nonQuery', () {
        expect(StatementRouter.isQuery(sql), isFalse);
      });
    }
  });

  group('前导注释', () {
    test('-- 行注释', () {
      expect(StatementRouter.isQuery('-- 注释\nSELECT * FROM t'), isTrue);
      expect(
        StatementRouter.isQuery('-- 注释\nCREATE TABLE t (x INT)'),
        isFalse,
      );
    });

    test('/* */ 块注释', () {
      expect(StatementRouter.isQuery('/* hi */ SELECT 1'), isTrue);
      expect(StatementRouter.isQuery('/* hi */ DELETE FROM t'), isFalse);
    });

    test('纯注释/空白', () {
      expect(StatementRouter.isQuery('-- only comment'), isFalse);
      expect(StatementRouter.isQuery('/* only */'), isFalse);
    });
  });

  test('关键字前缀启发式：SHOW 系均命中', () {
    expect(StatementRouter.isQuery('SHOWX'), isTrue);
    expect(StatementRouter.isQuery('SET X'), isFalse);
    expect(StatementRouter.isQuery('SELECTTOP'), isTrue);
  });
}
