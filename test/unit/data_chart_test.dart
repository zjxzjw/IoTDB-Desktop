import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/features/data/presentation/data_chart.dart';

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
  group('chartSeries', () {
    test('多序列解析', () {
      final r = result(
        columns: ['time', 'temperature', 'humidity'],
        rows: [
          [1000, 1.0, 10.0],
          [2000, 2.0, null],
          [3000, null, 30.0],
        ],
      );
      final series = chartSeries(r);
      expect(series.length, 2);
      expect(series[0].name, 'temperature');
      expect(series[1].name, 'humidity');
      expect(series[0].spots.length, 2);
      expect(series[0].spots.first.x, 1000);
      expect(series[0].spots.first.y, 1.0);
      // null 值点被跳过
      expect(series[1].spots.length, 2);
      expect(series[1].spots.map((s) => s.y), [10.0, 30.0]);
    });

    test('time 列大小写不敏感（Time）', () {
      final r = result(
        columns: ['Time', 'v'],
        rows: [
          [100, 5.5],
        ],
      );
      final series = chartSeries(r);
      expect(series.length, 1);
      expect(series.single.spots.first.x, 100);
    });

    test('无 time 列时不产生点', () {
      final r = result(
        columns: ['v'],
        rows: [
          [1.0],
          [2.0],
        ],
      );
      expect(chartSeries(r).single.spots, isEmpty);
    });

    test('空结果', () {
      final r = result(columns: ['time', 'v'], rows: []);
      expect(chartSeries(r).single.spots, isEmpty);
    });
  });
}
