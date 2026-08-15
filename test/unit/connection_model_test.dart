import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/models/connection.dart';

void main() {
  final base = Connection(
    id: 'id-1',
    name: 'Prod',
    host: '10.0.0.1',
    port: 18080,
    username: 'root',
    password: 'secret',
    enableSSL: false,
    timeoutMs: 30000,
    rowLimit: 10000,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 2),
  );

  test('baseUrl：http / https', () {
    expect(base.baseUrl, 'http://10.0.0.1:18080');
    expect(base.copyWith(enableSSL: true).baseUrl, 'https://10.0.0.1:18080');
  });

  test('toJson 不包含明文密码', () {
    final json = base.toJson();
    expect(json.containsKey('password'), isFalse);
    expect(json['id'], 'id-1');
    expect(json['name'], 'Prod');
    expect(json['host'], '10.0.0.1');
    expect(json['port'], 18080);
    expect(json['username'], 'root');
    expect(json['rowLimit'], 10000);
    expect(json['createdAt'], DateTime(2025, 1, 1).millisecondsSinceEpoch);
  });

  test('fromJson 默认值与密码为空', () {
    final conn = Connection.fromJson({
      'id': 'a',
      'name': 'n',
      'host': 'h',
      'port': 18080,
      'username': 'u',
      'createdAt': 0,
      'updatedAt': 0,
    });
    expect(conn.password, '');
    expect(conn.enableSSL, isFalse);
    expect(conn.timeoutMs, 30000);
    expect(conn.rowLimit, isNull);
  });

  test('toRuntimeJson 含密码', () {
    final json = base.toRuntimeJson();
    expect(json['password'], 'secret');
  });

  test('copyWith 修改字段', () {
    final c = base.copyWith(name: 'New', port: 6667, rowLimit: () => 500);
    expect(c.name, 'New');
    expect(c.port, 6667);
    expect(c.rowLimit, 500);
    expect(c.id, 'id-1');
  });

  test('copyWith 清除 rowLimit', () {
    final c = base.copyWith(rowLimit: () => null);
    expect(c.rowLimit, isNull);
  });
}
