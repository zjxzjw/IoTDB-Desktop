import 'package:iotdb_desktop/core/models/connection.dart';

/// 构建测试用连接
Connection testConnection({
  String id = 'test-conn',
  String name = 'Test',
  String host = '127.0.0.1',
  int port = 18080,
  String username = 'root',
  String password = 'root',
  bool enableSSL = false,
  int timeoutMs = 30000,
  int? rowLimit = 10000,
}) {
  return Connection(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    password: password,
    enableSSL: enableSSL,
    timeoutMs: timeoutMs,
    rowLimit: rowLimit,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}
