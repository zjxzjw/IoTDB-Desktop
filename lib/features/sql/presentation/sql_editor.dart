import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

/// SQL 编辑器：re_editor + SQL 语法高亮 + 行号 + Cmd/Ctrl+Enter 执行
class SqlEditor extends StatefulWidget {
  final CodeLineEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onRun;

  const SqlEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onRun,
  });

  @override
  State<SqlEditor> createState() => _SqlEditorState();
}

class _SqlEditorState extends State<SqlEditor> {
  KeyEventCallback? _keyHandler;

  @override
  void initState() {
    super.initState();
    // re_editor 内部自行消费键盘事件，Focus 包装无法可靠拦截，
    // 改用 HardwareKeyboard 全局监听（仅编辑器聚焦时生效）。
    _keyHandler = _onKey;
    HardwareKeyboard.instance.addHandler(_keyHandler!);
  }

  @override
  void dispose() {
    final h = _keyHandler;
    if (h != null) {
      HardwareKeyboard.instance.removeHandler(h);
    }
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isRun =
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        event.logicalKey == LogicalKeyboardKey.enter;
    if (isRun) {
      widget.onRun();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return CodeEditor(
      controller: widget.controller,
      focusNode: widget.focusNode,
      style: CodeEditorStyle(
        fontSize: 13.5,
        fontFamily: 'Menlo',
        fontHeight: 1.5,
        codeTheme: CodeHighlightTheme(
          languages: {
            'sql': CodeHighlightThemeMode(mode: langSql),
          },
          theme: isLight ? atomOneLightTheme : atomOneDarkTheme,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
            return DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              minNumberCount: 3,
            );
          },
    );
  }
}
