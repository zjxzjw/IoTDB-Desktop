import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// mock path_provider 平台通道，返回一个临时目录（存储层测试用）
Future<Directory> mockPathProvider() async {
  final dir = await Directory.systemTemp.createTemp('iotdb_test_');
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'getApplicationSupportDirectory':
          case 'getTemporaryDirectory':
          case 'getApplicationDocumentsDirectory':
            return dir.path;
          default:
            return null;
        }
      });
  return dir;
}

void clearMockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
}
