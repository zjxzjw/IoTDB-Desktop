import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/connection.dart';
import 'package:iotdb_desktop/core/providers.dart';
import 'package:iotdb_desktop/features/dashboard/presentation/dashboard_page.dart';
import 'package:iotdb_desktop/features/data/presentation/data_browse_page.dart';
import 'package:iotdb_desktop/features/database/presentation/table_page.dart';
import 'package:iotdb_desktop/features/home/presentation/home_shell.dart';
import 'package:iotdb_desktop/features/sql/presentation/result_panel.dart';
import 'package:iotdb_desktop/features/sql/presentation/sql_editor.dart';
import 'package:iotdb_desktop/features/sql/presentation/sql_workbench_page.dart';
import 'package:iotdb_desktop/features/users/presentation/users_page.dart';
import 'package:re_editor/re_editor.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/test_connection.dart';

void main() {
  testWidgets('打开连接默认显示仪表盘，AppBar 导航可切换各独立页面', (tester) async {
    enlarge(tester);
    final client = FakeIotdbClient();
    await pumpWorkspace(tester, client);

    expect(find.byType(DashboardPage), findsOneWidget, reason: '默认应显示仪表盘');

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read;

    Future<void> go(WorkspacePage page, String tooltip, Type pageType) async {
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<WorkspacePage>),
          matching: find.byTooltip(tooltip),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '切页不应有渲染异常');
      expect(find.byType(pageType), findsOneWidget, reason: '$tooltip 页面应渲染');
      expect(ref(workspacePageProvider), page, reason: 'provider 应同步到 $page');
    }

    await go(WorkspacePage.sql, 'SQL 工作台', SqlWorkbenchPage);
    expect(find.byType(SqlEditor), findsOneWidget, reason: 'SQL 编辑器应渲染');
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(find.byType(ResultPanel), findsOneWidget, reason: '结果面板应直接在编辑器下方');
    expect(find.byType(TabBar), findsNothing, reason: '不应再有底部 Tab 切换条');

    await go(WorkspacePage.tables, '表管理', TablePage);
    await go(WorkspacePage.users, '用户与权限', UsersPage);
    await go(WorkspacePage.data, '数据浏览', DataBrowsePage);
    await go(WorkspacePage.dashboard, '仪表盘', DashboardPage);
  });

  testWidgets('SQL 页执行 SQL 后结果直接显示在编辑器下方（无需切换页面）', (tester) async {
    enlarge(tester);
    final client = FakeIotdbClient(
      queryResponses: {
        'SELECT 1': {
          'column_names': ['a'],
          'values': [
            [1],
          ],
          'data_types': ['INT32'],
        },
      },
    );
    await pumpWorkspace(tester, client);

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read;
    ref(workspacePageProvider.notifier).select(WorkspacePage.sql);
    await tester.pumpAndSettle();

    expect(find.byType(ResultPanel), findsOneWidget, reason: 'SQL 页应内联结果面板');

    // 写入 SQL 并执行（Cmd/Ctrl + Enter）
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller!.text = 'SELECT 1';
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '执行后不应有渲染异常');
    expect(find.byType(ResultPanel), findsOneWidget, reason: '结果面板仍在 SQL 页内');
    expect(ref(workspacePageProvider), WorkspacePage.sql, reason: '执行 SQL 不应切换页面');
    expect(find.text('1'), findsWidgets, reason: '结果数据应展示（编辑器与结果双份）');

    // 冲刷 re_editor 内部延迟任务（编辑器聚焦后光标闪烁计时器），避免残留计时器
    await tester.pump(const Duration(seconds: 10));
  });
}

void enlarge(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> pumpWorkspace(WidgetTester tester, FakeIotdbClient client) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        iotdbClientProvider.overrideWithValue(client),
        activeConnectionProvider.overrideWith(() => _FixedConnection()),
        databaseSelectionProvider.overrideWith(() => _FixedDbSelection('demo')),
      ],
      child: const MaterialApp(home: Scaffold(body: WorkspaceScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedConnection extends ActiveConnectionNotifier {
  @override
  Connection? build() => testConnection();
}

class _FixedDbSelection extends DatabaseSelectionNotifier {
  final String? value;
  _FixedDbSelection(this.value);
  @override
  String? build() => value;
}