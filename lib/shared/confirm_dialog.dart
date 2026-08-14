import 'package:flutter/material.dart';
import '../../core/theme/shadcn_tokens.dart';

/// 通用确认弹窗，返回 true 表示确认
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '确认',
  String cancelText = '取消',
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelText)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: confirmColor ?? ShadTokens.primary),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}
