import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/connection.dart';
import 'secure_store.dart';

/// 连接配置持久化：connections.json（脱敏）+ Keychain 密码
class ConnectionStore {
  final SecureStore secure;
  List<Connection> _connections = [];

  ConnectionStore(this.secure);

  List<Connection> get connections => List.unmodifiable(_connections);

  Connection? byId(String id) {
    for (final c in _connections) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}connections.json');
  }

  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final list = (raw['connections'] as List<dynamic>? ?? []);
      _connections = [];
      for (final item in list.cast<Map<String, dynamic>>()) {
        var conn = Connection.fromJson(item);
        final pwd = await secure.read(SecureStore.passwordKey(conn.id));
        conn = conn.copyWith(password: pwd ?? '');
        _connections.add(conn);
      }
    } catch (e) {
      // 配置损坏时重置为空列表，不影响启动
      _connections = [];
    }
  }

  Future<Connection> save(Connection input) async {
    final existing = _connections.where((c) => c.id == input.id).toList();
    final now = DateTime.now();
    Connection saved;
    if (existing.isNotEmpty) {
      saved = Connection(
        id: existing.first.id,
        name: input.name.trim(),
        host: input.host.trim(),
        port: input.port,
        username: input.username.trim(),
        password: input.password,
        enableSSL: input.enableSSL,
        timeoutMs: input.timeoutMs,
        rowLimit: input.rowLimit,
        createdAt: existing.first.createdAt,
        updatedAt: now,
      );
    } else {
      saved = Connection(
        id: input.id.isEmpty ? const Uuid().v4() : input.id,
        name: input.name.trim(),
        host: input.host.trim(),
        port: input.port,
        username: input.username.trim(),
        password: input.password,
        enableSSL: input.enableSSL,
        timeoutMs: input.timeoutMs,
        rowLimit: input.rowLimit,
        createdAt: now,
        updatedAt: now,
      );
    }
    if (input.password.isNotEmpty) {
      await secure.write(SecureStore.passwordKey(saved.id), input.password);
    }
    final idx = _connections.indexWhere((c) => c.id == saved.id);
    if (idx >= 0) {
      _connections[idx] = saved;
    } else {
      _connections.add(saved);
    }
    await _persist();
    return saved;
  }

  Future<void> remove(String id) async {
    _connections.removeWhere((c) => c.id == id);
    await secure.delete(SecureStore.passwordKey(id));
    await _persist();
  }

  Future<void> _persist() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final data = {'connections': _connections.map((c) => c.toJson()).toList()};
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}
