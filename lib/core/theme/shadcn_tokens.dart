import 'package:flutter/material.dart';

/// shadcn/ui 设计令牌（默认主题 · zinc 中性色板）
/// 来源：https://ui.shadcn.com/docs/theming（oklch 色值已转换为 sRGB）
abstract final class ShadTokens {
  // ---- 背景 / 前景 ----
  static const Color background = Color(0xFFFFFFFF); // oklch(1 0 0)
  static const Color backgroundDark = Color(0xFF09090B); // zinc-950
  static const Color foreground = Color(0xFF09090B); // zinc-950
  static const Color foregroundDark = Color(0xFFFAFAFA); // zinc-50

  // ---- 卡片（card / popover）----
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF18181B); // zinc-900

  // ---- muted / secondary / accent ----
  static const Color muted = Color(0xFFF4F4F5); // zinc-100
  static const Color mutedDark = Color(0xFF27272A); // zinc-800
  static const Color mutedForeground = Color(0xFFA1A1AA); // zinc-400
  static const Color mutedForegroundDark = Color(0xFF52525B); // zinc-600
  static const Color hover = Color(0xFFF4F4F5);
  static const Color hoverDark = Color(0xFF27272A);

  // ---- 主色（中性 primary）----
  static const Color primary = Color(0xFF18181B); // zinc-900
  static const Color primaryDark = Color(0xFFE4E4E7); // zinc-200
  static const Color primaryHover = Color(0xFF27272A); // primary/90
  static const Color primaryActive = Color(0xFF09090B);
  static const Color primaryDisabled = Color(0xFFD4D4D8); // zinc-300
  static const Color primaryForeground = Color(0xFFFAFAFA);
  static const Color primaryForegroundDark = Color(0xFF18181B);

  // ---- 焦点环（ring）----
  static const Color ring = Color(0xFFA1A1AA); // oklch(0.708 0 0)
  static const Color ringDark = Color(0xFF52525B); // oklch(0.556 0 0)

  // ---- 功能色 ----
  static const Color success = Color(0xFF22C55E); // green-500
  static const Color successDark = Color(0xFF4ADE80); // green-400
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color warningDark = Color(0xFFFBBF24); // amber-400
  static const Color destructive = Color(0xFFEF4444); // red-500
  static const Color destructiveDark = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFAFAFA);

  // ---- 边框 / 分隔 ----
  static const Color border = Color(0xFFE4E4E7); // zinc-200
  static const Color borderDark = Color(0xFF27272A); // zinc-800
  static const Color divider = Color(0xFFE4E4E7);
  static const Color dividerDark = Color(0xFF27272A);

  // ---- 侧边栏（--sidebar 令牌）----
  static const Color sidebar = Color(0xFFFAFAFA); // zinc-50
  static const Color sidebarDark = Color(0xFF18181B); // zinc-900
  static const Color sidebarHover = Color(0xFFE4E4E7); // zinc-200
  static const Color sidebarHoverDark = Color(0xFF27272A); // zinc-800
  static const Color sidebarActive = Color(0xFFE4E4E7); // zinc-200
  static const Color sidebarActiveDark = Color(0xFF27272A); // zinc-800

  // ---- 占位 / 禁用文字 ----
  static const Color placeholder = Color(0xFFA1A1AA);
  static const Color textDisabled = Color(0xFF71717A); // zinc-500

  // ---- 圆角（默认 --radius 0.5rem 体系）----
  static const double radiusSmall = 4;
  static const double radiusDefault = 6; // 按钮 / 输入框（rounded-md）
  static const double radiusMedium = 8; // 卡片（rounded-lg）
  static const double radiusLarge = 8; // 弹窗（rounded-lg）
  static const double radiusXl = 12;

  // ---- 间距（4px 栅格）----
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  // ---- 字号（text-xs / sm / base / xl）----
  static const double fontAux = 12;
  static const double fontBody = 14;
  static const double fontTitle = 16;
  static const double fontPage = 20;
}
