import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 敏感信息存储（当前兜底实现：本地文件 + 0600 权限 + base64 混淆）
/// 原 Keychain 实现因 ad-hoc 签名在 macOS 15+ 触发 -34018 无法使用，
/// 后续如有正式签名可换回 Keychain。接口不变，调用方无需改动。
class SecureStore {
  static String passwordKey(String connectionId) => 'conn_pwd_$connectionId';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}secrets.json');
  }

  Future<Map<String, String>> _readAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is Map<String, dynamic>) {
        return raw.map((k, v) => MapEntry(k, v is String ? v : ''));
      }
    } catch (_) {
      // 文件损坏/不存在时按空处理
    }
    return {};
  }

  Future<void> _writeAll(Map<String, String> data) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    await Process.run('chmod', ['600', file.path]);
  }

  Future<String?> read(String key) async {
    final all = await _readAll();
    final value = all[key];
    if (value == null || value.isEmpty) return null;
    return utf8.decode(base64Decode(value));
  }

  Future<void> write(String key, String value) async {
    final all = await _readAll();
    all[key] = base64Encode(utf8.encode(value));
    await _writeAll(all);
  }

  Future<void> delete(String key) async {
    final all = await _readAll();
    all.remove(key);
    await _writeAll(all);
  }
}
