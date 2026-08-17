import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/query_result.dart';
import 'package:iotdb_desktop/core/providers.dart';
import 'package:iotdb_desktop/features/dashboard/presentation/dashboard_page.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/pump.dart';

void main() {
  Future<QueryResult> makeDatabases(int count) async => qr(
    columns: const ['Database', 'TTL(ms)'],
    rows: [for (var i = 0; i < count; i++) ['db_$i', 86400000]],
  );

  Future<ProviderContainer> pumpDashboard(
    WidgetTester tester,
    QueryResult dbList,
  ) async {
    enlargeSurface(tester);
    await tester.pumpWidget(
      wrapWithProvider(
        client: FakeIotdbClient(),
        dbList: dbList,
        child: const DashboardPage(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DashboardPage)),
    );
  }

  IconButton chevron(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  group('仪表盘数据库列表分页', () {
    testWidgets('库多于 10 个时首屏只渲染第一页并显示分页条', (tester) async {
      await pumpDashboard(tester, await makeDatabases(12));

      for (var i = 0; i < 10; i++) {
        expect(find.text('db_$i'), findsOneWidget, reason: '首页应显示 db_$i');
      }
      expect(find.text('db_10'), findsNothing, reason: '首页不应显示 db_10');
      expect(find.text('db_11'), findsNothing, reason: '首页不应显示 db_11');

      expect(find.text('共 12 个库'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(chevron(tester, Icons.chevron_left).onPressed, isNull,
          reason: '首页上一页禁用');
      expect(chevron(tester, Icons.chevron_right).onPressed, isNotNull);
    });

    testWidgets('翻页可查看剩余库，末页下一页禁用', (tester) async {
      await pumpDashboard(tester, await makeDatabases(12));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(find.text('db_10'), findsOneWidget);
      expect(find.text('db_11'), findsOneWidget);
      expect(find.text('db_0'), findsNothing, reason: '末页不应显示 db_0');
      expect(find.text('2 / 2'), findsOneWidget);
      expect(chevron(tester, Icons.chevron_right).onPressed, isNull,
          reason: '末页下一页禁用');
      expect(chevron(tester, Icons.chevron_left).onPressed, isNotNull);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(find.text('db_0'), findsOneWidget, reason: '上一页应回到首页');
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('少于等于 10 个库时不显示分页条', (tester) async {
      await pumpDashboard(tester, await makeDatabases(10));

      expect(find.text('db_9'), findsOneWidget);
      expect(find.text('共 10 个库'), findsNothing, reason: '单页不应显示分页条');
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('点击行仍能选中数据库并跳转表管理页', (tester) async {
      final container = await pumpDashboard(tester, await makeDatabases(12));

      await tester.tap(find.text('db_3'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(container.read(databaseSelectionProvider), 'db_3',
          reason: '应选中被点击的库');
      expect(container.read(workspacePageProvider), WorkspacePage.tables);
    });
  });
}
