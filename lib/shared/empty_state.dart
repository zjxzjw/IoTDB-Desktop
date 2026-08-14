import 'package:flutter/material.dart';
import 'package:remixicon/remixicon.dart';

import '../../core/theme/shadcn_tokens.dart';

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
          Icon(icon, size: 40, color: ShadTokens.placeholder),
          const SizedBox(height: ShadTokens.space3),
          Text(title, style: const TextStyle(fontSize: ShadTokens.fontBody, color: ShadTokens.mutedForeground)),
          if (description != null) ...[
            const SizedBox(height: ShadTokens.space1),
            Text(
              description!,
              style: const TextStyle(fontSize: ShadTokens.fontAux, color: ShadTokens.placeholder),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: ShadTokens.space4),
            action!,
          ],
        ],
      ),
    );
  }
}
