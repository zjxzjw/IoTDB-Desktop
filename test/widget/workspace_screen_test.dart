import 'package:flutter/foundation.dart';
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

  testWidgets('SQL 页切换离开后返回，编辑器内容与执行结果保留', (tester) async {
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

    // 输入 SQL 并执行
    var editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller!.text = 'SELECT 1';
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump();
    await tester.pump();
    expect(find.text('1'), findsWidgets, reason: '执行后应展示结果数据');

    // 切到表管理再切回 SQL
    ref(workspacePageProvider.notifier).select(WorkspacePage.tables);
    await tester.pumpAndSettle();
    expect(find.byType(TablePage), findsOneWidget);

    ref(workspacePageProvider.notifier).select(WorkspacePage.sql);
    await tester.pumpAndSettle();

    // 编辑器内容与结果应保留
    editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.controller!.text, 'SELECT 1', reason: '切回后编辑器内容应保留');
    expect(find.text('1'), findsWidgets, reason: '切回后执行结果应保留');

    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('SQL 页有选中时只执行选中语句，无选中执行全部', (tester) async {
    // 覆盖为 macOS：让 re_editor 走桌面分支（默认测试平台为 android 会触发其移动端换行逻辑）
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    enlarge(tester);
    final client = FakeIotdbClient();
    await pumpWorkspace(tester, client);

    final ref = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read;
    ref(workspacePageProvider.notifier).select(WorkspacePage.sql);
    await tester.pumpAndSettle();

    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    // 先聚焦编辑器，再同帧写入内容与选中（模拟真实操作，避免 re_editor 内部状态不同步）
    editor.focusNode?.requestFocus();
    await tester.pump();
    expect(find.text('运行'), findsOneWidget, reason: '无选中时按钮显示「运行」');

    editor.controller!.text = 'SELECT 1; SELECT 2;';
    // 仅选中第二条语句 "SELECT 2;"（偏移 10..19）
    editor.controller!.selection = const CodeLineSelection(
      baseIndex: 0,
      baseOffset: 10,
      extentIndex: 0,
      extentOffset: 19,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('运行选中'), findsOneWidget, reason: '有选中时按钮显示「运行选中」');

    // Cmd+Enter：仅执行选中语句
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump();
    await tester.pump();
    List<String> selectSql() =>
        client.querySql.where((s) => s.startsWith('SELECT')).toList();
    expect(selectSql(), ['SELECT 2'], reason: '仅执行选中的语句');

    // 清除选中后回到「运行」，点击按钮执行全部
    // （同帧重设文本+折叠选中，避免 re_editor 对跨帧程序化改动的不同步）
    editor.controller!.text = 'SELECT 1; SELECT 2;';
    editor.controller!.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    await tester.pump();
    await tester.pump();
    expect(find.text('运行'), findsOneWidget, reason: '清除选中后按钮回到「运行」');

    await tester.tap(find.text('运行'));
    await tester.pump();
    await tester.pump();
    expect(selectSql(), ['SELECT 2', 'SELECT 1', 'SELECT 2'], reason: '无选中时执行全部语句');

    debugDefaultTargetPlatformOverride = null;
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