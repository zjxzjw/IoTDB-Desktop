import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/connection.dart';
import 'package:iotdb_desktop/core/storage/connection_store.dart';
import 'package:iotdb_desktop/core/storage/secure_store.dart';

import '../helpers/path_provider_mock.dart';
import '../helpers/test_connection.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await mockPathProvider();
  });
  tearDown(() async {
    clearMockPathProvider();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  Connection conn({String id = 'c1', String name = 'Prod', String pwd = 'secret'}) {
    return testConnection(id: id, name: name, password: pwd);
  }

  test('save 后新实例 load 恢复（含密码回填）', () async {
    final store = ConnectionStore(SecureStore());
    await store.load();
    final saved = await store.save(conn());
    expect(saved.password, 'secret');

    final fresh = ConnectionStore(SecureStore());
    await fresh.load();
    expect(fresh.connections.length, 1);
    expect(fresh.connections.first.id, 'c1');
    expect(fresh.connections.first.name, 'Prod');
    expect(fresh.connections.first.password, 'secret');
  });

  test('save 更新已有连接：保留 createdAt，更新 updatedAt/name', () async {
    final store = ConnectionStore(SecureStore());
    await store.load();
    final first = await store.save(conn(name: 'Old'));
    final createdAt = first.createdAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    final updated = await store.save(conn(name: 'New'));
    expect(updated.createdAt, createdAt);
    expect(updated.name, 'New');
    expect(store.connections.length, 1);
    expect(store.connections.single.name, 'New');
  });

  test('id 为空自动生成', () async {
    final store = ConnectionStore(SecureStore());
    await store.load();
    final saved = await store.save(conn(id: ''));
    expect(saved.id, isNotEmpty);
  });

  test('remove 删除', () async {
    final store = ConnectionStore(SecureStore());
    await store.load();
    await store.save(conn());
    await store.remove('c1');
    expect(store.connections, isEmpty);
    expect(store.byId('c1'), isNull);
  });

  test('byId 查找', () async {
    final store = ConnectionStore(SecureStore());
    await store.load();
    await store.save(conn());
    await store.save(conn(id: 'c2', name: 'Dev', pwd: ''));
    expect(store.byId('c2')?.name, 'Dev');
    expect(store.byId('missing'), isNull);
  });

  test('损坏的 connections.json 容错为空列表', () async {
    final file = File('${dir.path}${Platform.pathSeparator}connections.json');
    await file.writeAsString('not json {{{');
    final store = ConnectionStore(SecureStore());
    await store.load();
    expect(store.connections, isEmpty);
  });
}
