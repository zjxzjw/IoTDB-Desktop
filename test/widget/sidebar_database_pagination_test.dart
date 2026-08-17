import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/connection.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/core/providers.dart';
import 'package:iotdb_desktop/features/connections/presentation/connection_sidebar.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';
import '../helpers/test_connection.dart';

void main() {
  Future<QueryResult> makeDatabases(int count, {String prefix = 'db'}) async =>
      qr(
        columns: const ['Database'],
        rows: [for (var i = 0; i < count; i++) ['${prefix}_$i']],
      );

  Widget buildSidebar({
    required List<Connection> connections,
    required Future<QueryResult> Function(Connection conn) dbListFor,
    void Function(Connection conn, String db)? onSelectDatabase,
  }) {
    return ProviderScope(
      overrides: [
        iotdbClientProvider.overrideWithValue(FakeIotdbClient()),
        connectionDatabaseListProvider.overrideWith(
          (ref, conn) async => dbListFor(conn),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ConnectionSidebar(
              connections: connections,
              loading: false,
              onOpen: (_) {},
              onTest: (_) {},
              onEdit: (_) {},
              onDelete: (_) {},
              onDisconnect: (_) {},
              onSelectDatabase: (c, db) => onSelectDatabase?.call(c, db),
            ),
          ),
        ),
      ),
    );
  }

  /// 展开侧边栏中的连接（点击连接名称）
  Future<void> expandConnection(
    WidgetTester tester,
    String name,
  ) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('侧边栏数据库列表分页（底部栏 + 手风琴）', () {
    testWidgets('库多于 10 个时首屏只显示前 10 个，底部栏出现加载按钮', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(12),
        ),
      );
      await expandConnection(tester, 'Test');

      for (var i = 0; i < 10; i++) {
        expect(find.text('db_$i'), findsOneWidget, reason: '首屏应显示 db_$i');
      }
      expect(find.text('db_10'), findsNothing, reason: '首屏不应显示 db_10');
      expect(find.text('db_11'), findsNothing, reason: '首屏不应显示 db_11');

      expect(find.text('已显示 10 / 12'), findsOneWidget);
      expect(find.text('加载更多'), findsOneWidget);
      expect(find.text('全部加载'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(10 / 12, 0.001),
          reason: '进度条应反映已加载比例');
    });

    testWidgets('点击「加载更多」追加显示下一批数据库', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(25),
        ),
      );
      await expandConnection(tester, 'Test');

      expect(find.text('db_9'), findsOneWidget);
      expect(find.text('db_10'), findsNothing);

      await tester.tap(find.text('加载更多'));
      await tester.pump();

      expect(find.text('已显示 20 / 25'), findsOneWidget);
      expect(find.text('db_10'), findsOneWidget, reason: '追加后应显示 db_10');
      expect(find.text('db_19'), findsOneWidget, reason: '追加后应显示 db_19');
      expect(find.text('db_20'), findsNothing, reason: '尚未显示 db_20');
      expect(find.text('加载更多'), findsOneWidget);
      expect(find.text('全部加载'), findsOneWidget);
    });

    testWidgets('点击「全部加载」显示全部且仅隐藏按钮，计数与进度保留', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(12),
        ),
      );
      await expandConnection(tester, 'Test');

      await tester.tap(find.text('全部加载'));
      await tester.pump();

      expect(find.text('db_11'), findsOneWidget, reason: '应显示最后一个库');
      expect(find.text('已显示 12 / 12'), findsOneWidget,
          reason: '全部加载后计数保留');
      expect(find.text('加载更多'), findsNothing, reason: '全部加载后按钮隐藏');
      expect(find.text('全部加载'), findsNothing);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(1.0, 0.001),
          reason: '全部加载后进度条保留且满格');
    });

    testWidgets('少于等于 10 个库时不显示加载按钮，计数与进度保留', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(10),
        ),
      );
      await expandConnection(tester, 'Test');

      expect(find.text('db_9'), findsOneWidget);
      expect(find.text('加载更多'), findsNothing, reason: '单页不应显示加载更多');
      expect(find.text('全部加载'), findsNothing);
      expect(find.text('已显示 10 / 10'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(1.0, 0.001));
    });

    testWidgets('未展开任何连接时不显示底部栏', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(12),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加载更多'), findsNothing, reason: '未展开时不应显示加载更多');
      expect(find.text('全部加载'), findsNothing);
    });

    testWidgets('手风琴：展开新连接会收起旧连接，底部栏作用于新连接', (tester) async {
      enlargeSurface(tester);
      final connA = testConnection(id: 'a', name: 'Conn A');
      final connB = testConnection(id: 'b', name: 'Conn B');
      await tester.pumpWidget(
        buildSidebar(
          connections: [connA, connB],
          dbListFor: (c) async => c.id == 'a'
              ? makeDatabases(25, prefix: 'a')
              : makeDatabases(12, prefix: 'b'),
        ),
      );

      await expandConnection(tester, 'Conn A');
      expect(find.text('已显示 10 / 25'), findsOneWidget, reason: '底部栏应作用于 A');
      expect(find.text('a_0'), findsOneWidget);

      await expandConnection(tester, 'Conn B');
      expect(find.text('a_0'), findsNothing, reason: 'A 的列表应被收起');
      expect(find.text('b_0'), findsOneWidget);
      expect(find.text('已显示 10 / 12'), findsOneWidget, reason: '底部栏应切换为作用于 B');
      expect(find.text('b_10'), findsNothing, reason: 'B 首屏只显示前 10 个');
      expect(find.text('b_11'), findsNothing);

      // 底部栏操作作用于 B
      await tester.tap(find.text('全部加载'));
      await tester.pump();
      expect(find.text('b_11'), findsOneWidget, reason: 'B 全部加载后应显示最后一个库');
    });

    testWidgets('再次点击已展开的连接会收起列表且底部栏消失', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(12),
        ),
      );
      await expandConnection(tester, 'Test');
      expect(find.text('已显示 10 / 12'), findsOneWidget);

      await expandConnection(tester, 'Test');
      expect(find.text('db_0'), findsNothing, reason: '收起后应隐藏列表');
      expect(find.text('加载更多'), findsNothing);
      expect(find.text('全部加载'), findsNothing);
    });

    testWidgets('点击库仍能触发选择回调', (tester) async {
      enlargeSurface(tester);
      final conn = testConnection();
      String? selected;
      await tester.pumpWidget(
        buildSidebar(
          connections: [conn],
          dbListFor: (_) async => makeDatabases(12),
          onSelectDatabase: (c, db) => selected = db,
        ),
      );
      await expandConnection(tester, 'Test');

      await tester.tap(find.text('db_3'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(selected, 'db_3', reason: '应选中被点击的库');
    });
  });
}
