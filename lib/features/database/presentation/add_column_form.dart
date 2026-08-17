import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../data/database_providers.dart';
import 'column_defs_editor.dart';

/// 给表添加列（居中弹窗）：仅允许 TAG / ATTRIBUTE / FIELD 列
Future<void> showAddColumnDialog(
  BuildContext context,
  WidgetRef ref, {
  required String db,
  required String table,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    useSafeArea: true,
    builder: (context) => AddColumnDialog(db: db, table: table),
  );
}

class AddColumnDialog extends ConsumerStatefulWidget {
  final String db;
  final String table;

  const AddColumnDialog({super.key, required this.db, required this.table});

  @override
  ConsumerState<AddColumnDialog> createState() => _AddColumnDialogState();
}

class _AddColumnDialogState extends ConsumerState<AddColumnDialog> {
  List<TableColumn> _columns = [];
  bool _submitting = false;

  Future<void> _submit() async {
    if (_columns.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写列名')));
      return;
    }
    setState(() => _submitting = true);
    try {
      for (final col in _columns) {
        await ref
            .read(iotdbClientProvider)
            .nonQuery(SqlBuilder.alterAddColumn(widget.db, widget.table, col));
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加 ${_columns.length} 列')));
      _invalidateSchema();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _invalidateSchema() {
    ref.invalidate(columnListProvider(TableRef(widget.db, widget.table)));
    ref.invalidate(tableListProvider(widget.db));
    final conn = ref.read(activeConnectionProvider);
    if (conn != null) {
      ref.invalidate(connectionTableListProvider(TableScope(conn, widget.db)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadTokens.radiusLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              ShadTokens.space6,
              ShadTokens.space4,
              ShadTokens.space6,
              ShadTokens.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      RemixIcons.add_circle_line,
                      size: 18,
                      color: ShadTokens.primary,
                    ),
                    const SizedBox(width: ShadTokens.space2),
                    Expanded(
                      child: Text(
                        '新建列 · ${widget.table}',
                        style: const TextStyle(
                          fontSize: ShadTokens.fontTitle,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(RemixIcons.close_line, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 24),
                ColumnDefsEditor(
                  allowTimeCategory: false,
                  onChanged: (cols) => _columns = cols,
                ),
                const SizedBox(height: ShadTokens.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: ShadTokens.space2),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}