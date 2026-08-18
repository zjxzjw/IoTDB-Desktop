import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/connection.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shadcn_tokens.dart';
import '../../../core/utils/sql_builder.dart';

/// 删除数据库二次确认弹窗。
///
/// 要求用户手动输入目标数据库名称进行校验，仅当输入与目标库名完全一致时，
/// 红色确认按钮才可点击。确认后执行 DROP DATABASE 并刷新相关列表。
Future<void> showDropDatabaseDialog(
  BuildContext context,
  WidgetRef ref, {
  required Connection conn,
  required String db,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  // 是否允许点击删除按钮（输入与目标库名完全一致）
  var canDelete = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('删除数据库'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '此操作将永久删除数据库「$db」及其全部数据，不可恢复。',
                    style: const TextStyle(
                      fontSize: ShadTokens.fontBody,
                      color: ShadTokens.destructive,
                    ),
                  ),
                  const SizedBox(height: ShadTokens.space3),
                  Text(
                    '请输入数据库名称「$db」以确认：',
                    style: const TextStyle(fontSize: ShadTokens.fontBody),
                  ),
                  const SizedBox(height: ShadTokens.space2),
                  TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: db,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        canDelete = value.trim() == db;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ShadTokens.destructive,
                ),
                onPressed: canDelete
                    ? () async {
                        Navigator.pop(ctx);
                        await _dropDatabase(ref, conn: conn, db: db, context: context);
                      }
                    : null,
                child: const Text('删除'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _dropDatabase(
  WidgetRef ref, {
  required Connection conn,
  required String db,
  required BuildContext context,
}) async {
  try {
    await ref.read(iotdbClientProvider).nonQuery(SqlBuilder.dropDatabase(db));
    if (!context.mounted) return;
    // 若删除的是当前选中库，清理选中状态
    if (ref.read(databaseSelectionProvider) == db) {
      ref.read(databaseSelectionProvider.notifier).clear();
    }
    // 刷新侧栏与主区域数据库列表
    ref.invalidate(connectionDatabaseListProvider(conn));
    ref.invalidate(databaseListProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除数据库「$db」')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
  }
}
