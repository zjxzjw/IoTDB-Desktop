import 'package:flutter/material.dart';

/// TDesign 设计令牌（来自 https://tdesign.tencent.com/design/ 色板/圆角/字号规范）
abstract final class TdTokens {
  // 品牌色
  static const Color brand = Color(0xFF0052D9);
  static const Color brandHover = Color(0xFF2667D4);
  static const Color brandFocus = Color(0x1A0052D9); // 10% 透明
  static const Color brandDisabled = Color(0xFFB8CBE8);
  static const Color brandActive = Color(0xFF0048B8);

  // 功能色
  static const Color success = Color(0xFF00A870);
  static const Color successHover = Color(0xFF23C343);
  static const Color warning = Color(0xFFED7B2F);
  static const Color danger = Color(0xFFD54941);
  static const Color dangerHover = Color(0xE6D54941);

  // 中性文字
  static const Color textPrimary = Color(0xE6000000); // rgba(0,0,0,.9)
  static const Color textSecondary = Color(0x99000000); // .6
  static const Color textPlaceholder = Color(0x66000000); // .4
  static const Color textDisabled = Color(0x42000000); // .26

  // 边框与分隔
  static const Color border = Color(0x26000000); // rgba(0,0,0,.15)
  static const Color divider = Color(0x0F000000); // rgba(0,0,0,.06)

  // 背景
  static const Color bgPage = Color(0xFFF6F6F6);
  static const Color bgContainer = Colors.white;
  static const Color bgHover = Color(0x0A000000); // 4%
  static const Color bgComponent = Color(0x0F000000); // 6%

  // 圆角
  static const double radiusSmall = 3;
  static const double radiusDefault = 6;
  static const double radiusMedium = 9;
  static const double radiusLarge = 12;
  static const double radiusXl = 24;

  // 间距（4px 栅格）
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  // 字号
  static const double fontAux = 12;
  static const double fontBody = 14;
  static const double fontTitle = 16;
  static const double fontPage = 20;
}

/// 主题扩展：全局暴露 TDesign 令牌，供任意组件读取
class TdTheme extends InheritedWidget {
  const TdTheme({super.key, required super.child});

  static TdTheme of(BuildContext context) {
    final t = context.dependOnInheritedWidgetOfExactType<TdTheme>();
    assert(t != null, '未找到 TdTheme，请确保在 MaterialApp 内使用');
    return t!;
  }

  @override
  bool updateShouldNotify(TdTheme oldWidget) => false;
}
