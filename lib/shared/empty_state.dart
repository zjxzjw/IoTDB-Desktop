import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../core/theme/tdesign_tokens.dart';

/// 空状态占位（图标 + 标题 + 可选描述/按钮）
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon = RemixIcons.inbox_line,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: TdTokens.textPlaceholder),
          const SizedBox(height: TdTokens.space3),
          Text(title, style: const TextStyle(fontSize: TdTokens.fontBody, color: TdTokens.textSecondary)),
          if (description != null) ...[
            const SizedBox(height: TdTokens.space1),
            Text(
              description!,
              style: const TextStyle(fontSize: TdTokens.fontAux, color: TdTokens.textPlaceholder),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: TdTokens.space4),
            action!,
          ],
        ],
      ),
    );
  }
}
