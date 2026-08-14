import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/connection.dart';
import 'models/query_result.dart';
import 'network/iotdb_client.dart';
import 'storage/app_settings_store.dart';
import 'storage/connection_store.dart';
import 'storage/secure_store.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => AppSettingsStore(),
);

/// 侧边栏宽度（启动时从磁盘加载，拖拽调整后持久化）
final sidebarWidthProvider =
    AsyncNotifierProvider<SidebarWidthNotifier, double>(
      SidebarWidthNotifier.new,
    );

class SidebarWidthNotifier extends AsyncNotifier<double> {
  AppSettingsStore get _store => ref.read(appSettingsStoreProvider);

  @override
  Future<double> build() => _store.loadSidebarWidth();

  Future<void> setWidth(double width) async {
    final clamped = width.clamp(
      AppSettingsStore.minSidebarWidth,
      AppSettingsStore.maxSidebarWidth,
    );
    state = AsyncData(clamped);
    await _store.saveSidebarWidth(clamped);
  }
}

/// 主题模式（浅色 / 深色 / 跟随系统，持久化）
final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
      ThemeModeNotifier.new,
    );

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  AppSettingsStore get _store => ref.read(appSettingsStoreProvider);

  @override
  Future<ThemeMode> build() => _store.loadThemeMode();

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await _store.saveThemeMode(mode);
  }
}

/// 连接列表（AsyncNotifier：build 时从磁盘加载）
final connectionStoreProvider =
    AsyncNotifierProvider<ConnectionStoreNotifier, List<Connection>>(
      ConnectionStoreNotifier.new,
    );

class ConnectionStoreNotifier extends AsyncNotifier<List<Connection>> {
  ConnectionStore get _store => ConnectionStore(ref.read(secureStoreProvider));

  @override
  Future<List<Connection>> build() async {
    final store = _store;
    await store.load();
    return store.connections;
  }

  Future<Connection> save(Connection input) async {
    final store = _store;
    final saved = await store.save(input);
    state = AsyncData(store.connections);
    return saved;
  }

  Future<void> remove(String id) async {
    final store = _store;
    await store.remove(id);
    state = AsyncData(store.connections);
  }
}

/// 当前打开工作区的连接
final activeConnectionProvider =
    NotifierProvider<ActiveConnectionNotifier, Connection?>(
      ActiveConnectionNotifier.new,
    );

class ActiveConnectionNotifier extends Notifier<Connection?> {
  @override
  Connection? build() => null;

  void set(Connection conn) => state = conn;

  void clear() => state = null;
}

/// 当前连接的 REST 客户端（随 activeConnection 变化重建）
final iotdbClientProvider = Provider<IotdbClient>((ref) {
  final conn = ref.watch(activeConnectionProvider);
  if (conn == null) {
    throw StateError('当前未打开任何连接');
  }
  return IotdbClient(conn);
});

/// 数据库列表（SHOW DATABASES DETAILS，随连接/刷新重建）
final databaseListProvider =
    AsyncNotifierProvider<DatabaseListNotifier, QueryResult>(
      DatabaseListNotifier.new,
    );

class DatabaseListNotifier extends AsyncNotifier<QueryResult> {
  @override
  Future<QueryResult> build() async {
    final client = ref.watch(iotdbClientProvider);
    return client.query('SHOW DATABASES DETAILS');
  }
}
