import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_highlighter.dart';

/// SQL 编辑器：CodeField + 关键字/测点路径补全 + Cmd/Ctrl+Enter 运行
class SqlEditor extends StatefulWidget {
  final CodeController controller;
  final FocusNode focusNode;
  final VoidCallback onRun;
  final List<String> timeseriesPaths;

  const SqlEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onRun,
    required this.timeseriesPaths,
  });

  @override
  State<SqlEditor> createState() => _SqlEditorState();
}

class _SqlEditorState extends State<SqlEditor> {
  static final _wordRegExp = RegExp(r'[A-Za-z0-9_.\u4e00-\u9fa5]*$');

  List<String> _candidates = [];
  int _selected = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _onTextChanged();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(SqlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeseriesPaths != widget.timeseriesPaths) {
      _refreshCandidates();
    }
  }

  String _currentWord() {
    final text = widget.controller.text;
    final offset = widget.controller.selection.isValid
        ? widget.controller.selection.start
        : text.length;
    final before = offset > 0 ? text.substring(0, offset) : '';
    return _wordRegExp.firstMatch(before)?.group(0) ?? '';
  }

  void _onTextChanged() {
    _refreshCandidates();
  }

  void _refreshCandidates() {
    if (!widget.focusNode.hasFocus) return;
    final word = _currentWord().trim();
    List<String> next;
    if (word.startsWith('root') || word.contains('.')) {
      next = widget.timeseriesPaths
          .where((p) => p.startsWith(word.isEmpty ? 'root' : word))
          .take(20)
          .toList();
      if (word.isEmpty) next = [];
    } else {
      next = SqlHighlighter.keywords
          .where((k) => k.toLowerCase().startsWith(word.toLowerCase()))
          .take(20)
          .toList();
    }
    if (next.isEmpty) {
      _candidates = [];
      _selected = -1;
      setState(() {});
      return;
    }
    _candidates = next;
    if (_selected >= next.length) _selected = -1;
    setState(() {});
  }

  void _insert(int index) {
    if (index < 0 || index >= _candidates.length) return;
    final word = _currentWord();
    final start = widget.controller.selection.start - word.length;
    widget.controller.text = widget.controller.text.replaceRange(start, widget.controller.selection.start, _candidates[index]);
    widget.controller.selection = TextSelection.collapsed(offset: start + _candidates[index].length);
    _candidates = [];
    _selected = -1;
    widget.focusNode.requestFocus();
    setState(() {});
  }

  void _moveSelection(int delta) {
    if (_candidates.isEmpty) return;
    setState(() {
      _selected = (_selected + delta) % _candidates.length;
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final isRun = event is KeyDownEvent &&
        (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed) &&
        event.logicalKey == LogicalKeyboardKey.enter;
    if (isRun) {
      widget.onRun();
      return KeyEventResult.handled;
    }
    if (_candidates.isNotEmpty && event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          _moveSelection(1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          _moveSelection(-1);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.tab:
        case LogicalKeyboardKey.enter:
          _insert(_selected < 0 ? 0 : _selected);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.escape:
          setState(() {
            _candidates = [];
            _selected = -1;
          });
          return KeyEventResult.handled;
        default:
          break;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Focus(
            onKeyEvent: _onKeyEvent,
            child: CodeField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textStyle: const TextStyle(fontSize: 13.5, fontFamily: 'Menlo', height: 1.5),
              cursorColor: Theme.of(context).colorScheme.primary,
              decoration: BoxDecoration(color: Colors.transparent),
            ),
          ),
        ),
        if (_candidates.isNotEmpty) _buildSuggestions(),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: ShadTokens.card,
        border: Border(top: BorderSide(color: ShadTokens.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(ShadTokens.space3, 4, ShadTokens.space3, 0),
            child: Text(
              '补全（Tab/Enter 插入，Esc 关闭）',
              style: const TextStyle(fontSize: 11, color: ShadTokens.placeholder),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _candidates.length,
              itemBuilder: (context, i) => InkWell(
                onTap: () => _insert(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: ShadTokens.space3, vertical: 5),
                  color: i == _selected ? ShadTokens.muted : null,
                  child: Row(
                    children: [
                      Icon(
                        _candidates[i].startsWith('root') ? RemixIcons.pulse_line : RemixIcons.function_line,
                        size: 14,
                        color: ShadTokens.mutedForeground,
                      ),
                      const SizedBox(width: ShadTokens.space2),
                      Expanded(
                        child: Text(
                          _candidates[i],
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
