import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// 应用级设置持久化：settings.json（侧边栏宽度、主题模式等）
class AppSettingsStore {
  static const double defaultSidebarWidth = 280;
  static const double minSidebarWidth = 200;
  static const double maxSidebarWidth = 600;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}settings.json');
  }

  Future<Map<String, dynamic>> _readAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) return raw;
    } catch (_) {
      // 文件损坏/不存在时按空处理
    }
    return {};
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<double> loadSidebarWidth() async {
    final all = await _readAll();
    final raw = all['sidebar_width'];
    if (raw is num) {
      return raw
          .toDouble()
          .clamp(minSidebarWidth, maxSidebarWidth)
          .toDouble();
    }
    return defaultSidebarWidth;
  }

  Future<void> saveSidebarWidth(double width) async {
    final all = await _readAll();
    all['sidebar_width'] = width.clamp(
      minSidebarWidth,
      maxSidebarWidth,
    );
    await _writeAll(all);
  }

  Future<ThemeMode> loadThemeMode() async {
    final all = await _readAll();
    return switch (all['theme_mode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final all = await _readAll();
    all['theme_mode'] = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _writeAll(all);
  }
}
