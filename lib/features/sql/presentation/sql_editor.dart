import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import 'sql_autocomplete.dart';

/// 去除 re_editor 对「带修饰键的 Enter」的换行绑定（Cmd/Ctrl/Alt+Enter），
/// 避免运行快捷键（Cmd/Ctrl+Enter）触发换行从而覆盖选中区域。
class SqlShortcutsActivatorsBuilder extends DefaultCodeShortcutsActivatorsBuilder {
  const SqlShortcutsActivatorsBuilder();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) {
    final activators = super.build(type);
    if (type != CodeShortcutType.newLine || activators == null) {
      return activators;
    }
    final filtered = activators.where((a) {
      if (a is! SingleActivator) return true;
      final key = a.trigger;
      final isEnter =
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter;
      if (!isEnter) return true;
      return !a.meta && !a.control && !a.alt;
    }).toList();
    return filtered;
  }
}

/// SQL 编辑器：re_editor + SQL 语法高亮 + 行号 + Cmd/Ctrl+Enter 执行 + 关键词补全
class SqlEditor extends StatefulWidget {
  final CodeLineEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onRun;

  /// 补全元数据；为空时仅保留 SQL 关键词补全
  final SqlAutocompleteData? autocompleteData;

  const SqlEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onRun,
    this.autocompleteData,
  });

  @override
  State<SqlEditor> createState() => _SqlEditorState();
}

class _SqlEditorState extends State<SqlEditor> {
  KeyEventCallback? _keyHandler;
  final SqlAutocompleteController _autoController = SqlAutocompleteController();

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
    // 补全下拉打开时：Tab 接受当前建议（Navicat 行为）
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        _autoController.isOpen) {
      _acceptAutocomplete();
      return true;
    }
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

  /// 复刻 re_editor 内部 onAutocomplete 的替换逻辑
  void _acceptAutocomplete() {
    final value = _autoController.value;
    if (value == null || value.prompts.isEmpty) return;
    final idx = value.index < value.prompts.length ? value.index : 0;
    final result = value.copyWith(index: idx).autocomplete;
    if (result.word.isEmpty) return;
    final selection = widget.controller.selection;
    if (!selection.isCollapsed) return;
    widget.controller.replaceSelection(
      result.word,
      selection.copyWith(
        baseOffset: selection.baseOffset - result.input.length,
      ),
    );
    widget.controller.selection = selection.copyWith(
      baseOffset: selection.baseOffset + result.selection.baseOffset,
      extentOffset: selection.extentOffset + result.selection.extentOffset,
    );
    _autoController.closed();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return CodeAutocomplete(
      viewBuilder: (context, notifier, onSelected) {
        return SqlAutocompleteView(
          notifier: notifier,
          onSelected: onSelected,
          controller: _autoController,
        );
      },
      promptsBuilder: SqlAutocompletePromptsBuilder(
        controller: widget.controller,
        data: widget.autocompleteData,
      ),
      child: CodeEditor(
        controller: widget.controller,
        focusNode: widget.focusNode,
        shortcutsActivatorsBuilder: const SqlShortcutsActivatorsBuilder(),
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
      ),
    );
  }
}
