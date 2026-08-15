import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:remixicon/remixicon.dart';

import '../../../core/models/table_meta.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';
import '../data/database_providers.dart';
import 'column_defs_editor.dart';

/// 给表添加列（ModalBottomSheet）：仅允许 TAG / ATTRIBUTE / FIELD 列
Future<void> showAddColumnSheet(
  BuildContext context,
  WidgetRef ref, {
  required String db,
  required String table,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShadTokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ShadTokens.radiusLarge),
      ),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: ShadTokens.space6,
        right: ShadTokens.space6,
        top: ShadTokens.space4,
        bottom: MediaQuery.of(context).viewInsets.bottom + ShadTokens.space6,
      ),
      child: AddColumnSheet(db: db, table: table),
    ),
  );
}

class AddColumnSheet extends ConsumerStatefulWidget {
  final String db;
  final String table;

  const AddColumnSheet({super.key, required this.db, required this.table});

  @override
  ConsumerState<AddColumnSheet> createState() => _AddColumnSheetState();
}

class _AddColumnSheetState extends ConsumerState<AddColumnSheet> {
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
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
          const SizedBox(height: ShadTokens.space3),
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
    );
  }
}
