import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/storage/app_settings_store.dart';

import '../helpers/path_provider_mock.dart';

void main() {
  setUp(mockPathProvider);
  tearDown(clearMockPathProvider);

  test('侧栏宽度默认值', () async {
    final store = AppSettingsStore();
    expect(await store.loadSidebarWidth(), AppSettingsStore.defaultSidebarWidth);
  });

  test('侧栏宽度保存/加载与 clamp', () async {
    final store = AppSettingsStore();
    await store.saveSidebarWidth(500);
    expect(await store.loadSidebarWidth(), 500);

    await store.saveSidebarWidth(99999);
    expect(await store.loadSidebarWidth(), AppSettingsStore.maxSidebarWidth);

    await store.saveSidebarWidth(10);
    expect(await store.loadSidebarWidth(), AppSettingsStore.minSidebarWidth);
  });

  test('主题模式往返', () async {
    final store = AppSettingsStore();
    expect(await store.loadThemeMode(), ThemeMode.system);

    await store.saveThemeMode(ThemeMode.dark);
    expect(await store.loadThemeMode(), ThemeMode.dark);

    await store.saveThemeMode(ThemeMode.light);
    expect(await store.loadThemeMode(), ThemeMode.light);
  });
}
