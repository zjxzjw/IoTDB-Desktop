import 'package:flutter/material.dart';

import 'shadcn_tokens.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isLight = brightness == Brightness.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: isLight ? ShadTokens.primary : ShadTokens.primaryDark,
    onPrimary: isLight
        ? ShadTokens.primaryForeground
        : ShadTokens.primaryForegroundDark,
    primaryContainer: isLight ? ShadTokens.muted : ShadTokens.mutedDark,
    onPrimaryContainer: isLight
        ? ShadTokens.foreground
        : ShadTokens.foregroundDark,
    secondary: isLight ? ShadTokens.muted : ShadTokens.mutedDark,
    onSecondary: isLight ? ShadTokens.foreground : ShadTokens.foregroundDark,
    surface: isLight ? ShadTokens.background : ShadTokens.backgroundDark,
    onSurface: isLight ? ShadTokens.foreground : ShadTokens.foregroundDark,
    error: ShadTokens.destructive,
    onError: ShadTokens.destructiveForeground,
    outline: isLight ? ShadTokens.border : ShadTokens.borderDark,
    outlineVariant: isLight ? ShadTokens.border : ShadTokens.borderDark,
    surfaceContainerHighest: isLight ? ShadTokens.muted : ShadTokens.mutedDark,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'PingFang SC',
    scaffoldBackgroundColor: isLight
        ? ShadTokens.background
        : ShadTokens.backgroundDark,
  );

  // 组件级令牌：shadcn/ui 统一外观（无阴影、纯边框、8px 圆角体系）
  return base.copyWith(
    dividerColor: isLight ? ShadTokens.divider : ShadTokens.dividerDark,
    dividerTheme: DividerThemeData(
      color: isLight ? ShadTokens.divider : ShadTokens.dividerDark,
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.copyWith(
      bodyMedium: const TextStyle(
        fontSize: ShadTokens.fontBody,
        color: ShadTokens.foreground,
      ),
      bodySmall: const TextStyle(
        fontSize: ShadTokens.fontAux,
        color: ShadTokens.mutedForeground,
      ),
      titleMedium: const TextStyle(
        fontSize: ShadTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: ShadTokens.foreground,
      ),
      titleLarge: const TextStyle(
        fontSize: ShadTokens.fontPage,
        fontWeight: FontWeight.w600,
        color: ShadTokens.foreground,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor:
          isLight ? ShadTokens.background : ShadTokens.backgroundDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        fontSize: ShadTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: ShadTokens.foreground,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isLight ? ShadTokens.card : ShadTokens.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusMedium),
        side: BorderSide(
          color: isLight ? ShadTokens.border : ShadTokens.borderDark,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isLight ? ShadTokens.card : ShadTokens.cardDark,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusLarge),
      ),
      titleTextStyle: const TextStyle(
        fontSize: ShadTokens.fontTitle,
        fontWeight: FontWeight.w600,
        color: ShadTokens.foreground,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      hoverColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ShadTokens.space3,
        vertical: 10,
      ),
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        borderSide: BorderSide(
          color: isLight ? ShadTokens.border : ShadTokens.borderDark,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        borderSide: BorderSide(
          color: isLight ? ShadTokens.border : ShadTokens.borderDark,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        borderSide: BorderSide(
          color: isLight ? ShadTokens.ring : ShadTokens.ringDark,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        borderSide: const BorderSide(color: ShadTokens.destructive),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ShadTokens.primary,
        foregroundColor: ShadTokens.primaryForeground,
        disabledBackgroundColor: ShadTokens.primaryDisabled,
        disabledForegroundColor: ShadTokens.primaryForeground.withValues(
          alpha: 0.5,
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        ),
        textStyle: const TextStyle(
          fontSize: ShadTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ShadTokens.primary,
        foregroundColor: ShadTokens.primaryForeground,
        disabledBackgroundColor: ShadTokens.primaryDisabled,
        disabledForegroundColor: ShadTokens.primaryForeground.withValues(
          alpha: 0.5,
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        ),
        textStyle: const TextStyle(
          fontSize: ShadTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ShadTokens.foreground,
        side: BorderSide(
          color: isLight ? ShadTokens.border : ShadTokens.borderDark,
        ),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
        ),
        textStyle: const TextStyle(
          fontSize: ShadTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ShadTokens.foreground,
        textStyle: const TextStyle(
          fontSize: ShadTokens.fontBody,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ShadTokens.foreground,
      unselectedLabelColor: ShadTokens.mutedForeground,
      indicatorColor: ShadTokens.foreground,
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? Colors.transparent
            : null,
      ),
      labelStyle: const TextStyle(
        fontSize: ShadTokens.fontBody,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: ShadTokens.fontBody),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        isLight ? ShadTokens.muted : ShadTokens.mutedDark,
      ),
      headingTextStyle: TextStyle(
        fontSize: ShadTokens.fontAux,
        fontWeight: FontWeight.w600,
        color: isLight
            ? ShadTokens.mutedForeground
            : ShadTokens.mutedForegroundDark,
      ),
      dataTextStyle: TextStyle(
        fontSize: ShadTokens.fontBody,
        color: isLight ? ShadTokens.foreground : ShadTokens.foregroundDark,
      ),
      dividerThickness: 1,
      horizontalMargin: ShadTokens.space4,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: isLight ? ShadTokens.primary : ShadTokens.primaryDark,
    ),
    iconTheme: IconThemeData(
      color: isLight ? ShadTokens.mutedForeground : ShadTokens.mutedForegroundDark,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isLight
          ? const Color(0xFF18181B)
          : const Color(0xFFE4E4E7),
      contentTextStyle: TextStyle(
        color: isLight ? Colors.white : Colors.black87,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ShadTokens.radiusDefault),
      ),
    ),
  );
}
