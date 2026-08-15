import 'package:flutter_test/flutter_test.dart';
import 'package:iotdb_desktop/core/storage/secure_store.dart';

import '../helpers/path_provider_mock.dart';

void main() {
  setUp(mockPathProvider);
  tearDown(clearMockPathProvider);

  test('写入后读取（base64 编解码）', () async {
    final store = SecureStore();
    await store.write('conn_pwd_a', 'my-secret');
    expect(await store.read('conn_pwd_a'), 'my-secret');
  });

  test('中文密码往返', () async {
    final store = SecureStore();
    await store.write('k', '密码@123');
    expect(await store.read('k'), '密码@123');
  });

  test('缺失 key 返回 null', () async {
    final store = SecureStore();
    expect(await store.read('nope'), isNull);
  });

  test('空值 key 返回 null', () async {
    final store = SecureStore();
    await store.write('k', '');
    expect(await store.read('k'), isNull);
  });

  test('delete 移除', () async {
    final store = SecureStore();
    await store.write('k', 'v');
    await store.delete('k');
    expect(await store.read('k'), isNull);
  });

  test('passwordKey 命名', () {
    expect(SecureStore.passwordKey('abc'), 'conn_pwd_abc');
  });
}
