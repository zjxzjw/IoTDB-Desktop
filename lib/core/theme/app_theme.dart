import 'package:flutter/material.dart';

import 'tdesign_tokens.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isLight = brightness == Brightness.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: TdTokens.brand,
        brightness: brightness,
        primary: TdTokens.brand,
        onPrimary: Colors.white,
        secondary: TdTokens.brandHover,
        error: TdTokens.danger,
        surface: isLight ? TdTokens.bgContainer : const Color(0xFF1F1F1F),
      ).copyWith(
        surfaceContainerHighest: isLight
            ? const Color(0xFFF3F3F3)
            : const Color(0xFF2A2A2A),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'PingFang SC',
    scaffoldBackgroundColor: isLight
        ? TdTokens.bgPage
        : const Color(0xFF171717),
  );

  // 组件级令牌：TDesign 风格的统一外观
  return base.copyWith(
    dividerColor: TdTokens.divider,
    dividerTheme: DividerThemeData(
      color: isLight ? TdTokens.divider : const Color(0xFF3A3A3A),
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.copyWith(
      bodyMedium: const TextStyle(
        fontSize: TdTokens.fontBody,
        color: TdTokens.textPrimary,
      ),
      bodySmall: const TextStyle(
        fontSize: TdTokens.fontAux,
        color: TdTokens.textSecondary,
      ),
      titleMedium: const TextStyle(
        fontSize: TdTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: TdTokens.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontSize: TdTokens.fontPage,
        fontWeight: FontWeight.w600,
        color: TdTokens.textPrimary,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: isLight ? TdTokens.bgContainer : const Color(0xFF1F1F1F),
      elevation: 0.5,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: TdTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: TdTokens.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0.5,
      color: isLight ? TdTokens.bgContainer : const Color(0xFF1F1F1F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        side: BorderSide(
          color: isLight ? TdTokens.border : const Color(0xFF3A3A3A),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isLight ? TdTokens.bgContainer : const Color(0xFF1F1F1F),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusLarge),
      ),
      titleTextStyle: const TextStyle(
        fontSize: TdTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: TdTokens.textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TdTokens.space3,
        vertical: 10,
      ),
      filled: true,
      fillColor: isLight ? const Color(0x0A000000) : const Color(0x1FFFFFFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        borderSide: BorderSide(
          color: isLight ? TdTokens.border : const Color(0xFF3A3A3A),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        borderSide: BorderSide(
          color: isLight ? TdTokens.border : const Color(0xFF3A3A3A),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        borderSide: const BorderSide(color: TdTokens.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        borderSide: const BorderSide(color: TdTokens.danger),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TdTokens.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: TdTokens.brandDisabled,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        ),
        textStyle: const TextStyle(
          fontSize: TdTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TdTokens.brand,
        side: const BorderSide(color: TdTokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
        ),
        textStyle: const TextStyle(
          fontSize: TdTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TdTokens.brand,
        textStyle: const TextStyle(
          fontSize: TdTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: TdTokens.brand,
      unselectedLabelColor: TdTokens.textSecondary,
      indicatorColor: TdTokens.brand,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(
        fontSize: TdTokens.fontBody,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: TdTokens.fontBody),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        isLight ? const Color(0xFFF7F7F7) : const Color(0xFF262626),
      ),
      headingTextStyle: TextStyle(
        fontSize: TdTokens.fontAux,
        fontWeight: FontWeight.w600,
        color: isLight ? TdTokens.textSecondary : Colors.white70,
      ),
      dataTextStyle: TextStyle(
        fontSize: TdTokens.fontBody,
        color: isLight ? TdTokens.textPrimary : Colors.white,
      ),
      dividerThickness: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TdTokens.brand,
    ),
    iconTheme: const IconThemeData(color: TdTokens.textSecondary),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight
          ? const Color(0xF2000000)
          : const Color(0xFFE8E8E8),
      contentTextStyle: TextStyle(color: isLight ? Colors.white : Colors.black),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TdTokens.radiusDefault),
      ),
    ),
  );
}
