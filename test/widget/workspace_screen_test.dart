import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/connection.dart';
import 'package:iotdb_desktop/core/providers.dart';
import 'package:iotdb_desktop/features/home/presentation/home_shell.dart';
import 'package:iotdb_desktop/features/sql/presentation/result_panel.dart';
import 'package:iotdb_desktop/features/sql/presentation/sql_editor.dart';
import 'package:re_editor/re_editor.dart';

import '../helpers/fake_iotdb_client.dart';
import '../helpers/test_connection.dart';

void main() {
  testWidgets('切到 Tab 工作区后正常渲染（SQL 编辑器 + 四个底部 Tab）', (tester) async {
    enlarge(tester);
    final client = FakeIotdbClient();
    await pumpWorkspace(tester, client);

    // 模拟侧栏 _selectDatabase：切到 tabs 视图并选中 tab 0
    final ref = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read;
    ref(workspaceViewProvider.notifier).showTabs();
    ref(workspaceTabProvider.notifier).select(0);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: '不应有渲染异常');
    expect(find.byType(SqlEditor), findsOneWidget, reason: 'SQL 编辑器应渲染');
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs.length, 4);
    for (final label in ['表管理', '用户与权限', '数据浏览', '执行结果']) {
      expect(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: '底部 Tab「$label」应存在',
      );
    }
    expect(find.byType(CodeEditor), findsOneWidget);
  });

  testWidgets('执行 SQL 后自动展开并切换到「执行结果」tab', (tester) async {
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

    // 模拟侧栏选中数据库：切到 tabs 视图
    final ref = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read;
    ref(workspaceViewProvider.notifier).showTabs();
    await tester.pumpAndSettle();

    // 进入 tabs 视图默认展开：底部内容区（IndexedStack）可见
    expect(find.byType(IndexedStack), findsOneWidget);

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
    expect(find.byType(ResultPanel), findsOneWidget, reason: '应展开并显示结果面板');

    // TabBar 选中态应同步到「执行结果」（index 3）
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 3, reason: 'TabBar 选中应切到执行结果');
    expect(ref(workspaceTabProvider), 3, reason: 'provider 也应切到执行结果');

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
