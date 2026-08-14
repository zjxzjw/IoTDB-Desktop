import 'package:flutter/material.dart';
import '../../core/theme/shadcn_tokens.dart';

/// 状态圆点（在线/离线/中性）
class StatusDot extends StatelessWidget {
  final Color color;
  final double size;

  const StatusDot({super.key, this.color = ShadTokens.placeholder, this.size = 8});

  const StatusDot.online({super.key, this.size = 8}) : color = ShadTokens.success;

  const StatusDot.offline({super.key, this.size = 8}) : color = ShadTokens.placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
