import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/connection.dart';
import '../models/query_result.dart';

class IotdbException implements Exception {
  final String message;
  final int? statusCode;
  final String? kind;

  const IotdbException(this.message, {this.statusCode, this.kind});

  @override
  String toString() => message;
}

/// IoTDB REST v2 客户端（dio 封装）
class IotdbClient {
  final Connection conn;
  final Dio dio;

  IotdbClient(this.conn)
      : dio = Dio(
          BaseOptions(
            baseUrl: conn.baseUrl,
            connectTimeout: Duration(milliseconds: conn.timeoutMs),
            receiveTimeout: Duration(milliseconds: conn.timeoutMs),
            sendTimeout: Duration(milliseconds: conn.timeoutMs),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path != '/ping') {
          final token = base64Encode(utf8.encode('${conn.username}:${conn.password}'));
          options.headers['Authorization'] = 'Basic $token';
        }
        handler.next(options);
      },
    ));
  }

  /// 检活，返回延迟毫秒数
  Future<int> ping() async {
    final sw = Stopwatch()..start();
    await dio.get('/ping');
    return sw.elapsedMilliseconds;
  }

  /// 数据/元数据查询
  Future<QueryResult> query(String sql, {int? rowLimit}) async {
    final sw = Stopwatch()..start();
    final payload = <String, dynamic>{'sql': sql};
    final limit = rowLimit ?? conn.rowLimit;
    if (limit != null && limit > 0) payload['row_limit'] = limit;
    final response = await _guard(() => dio.post('/rest/v2/query', data: payload));
    final json = response.data as Map<String, dynamic>;
    _throwIfServerError(json);
    return QueryResult.fromRestJson(json, sw.elapsedMilliseconds);
  }

  /// 非查询语句（DDL/DML/权限）
  Future<Map<String, dynamic>> nonQuery(String sql) async {
    final response = await _guard(() => dio.post('/rest/v2/nonQuery', data: {'sql': sql}));
    final json = (response.data as Map<String, dynamic>?) ?? {};
    _throwIfServerError(json);
    return json;
  }

  /// REST v2 对 SQL 错误返回 HTTP 200 + {code: !=200, message}，需显式抛出
  void _throwIfServerError(Map<String, dynamic> json) {
    final code = json['code'];
    if (code is num && code != 200) {
      throw IotdbException(
        json['message']?.toString() ?? '服务器返回错误（code $code）',
        statusCode: code.toInt(),
        kind: 'SERVER',
      );
    }
  }

  Future<Response<dynamic>> _guard(Future<Response<dynamic>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  IotdbException _mapError(DioException e) {
    final status = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return IotdbException(
          '请求超时（${conn.timeoutMs}ms），请检查网络或增大超时设置',
          kind: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return IotdbException(
          '无法连接服务器 ${conn.baseUrl}：请确认地址/端口正确、服务已启动且已开启 REST 服务（enable_rest_service=true）',
          kind: 'CONNECTION',
        );
      default:
        break;
    }
    if (status == 401) return const IotdbException('认证失败：用户名或密码错误', statusCode: 401, kind: 'AUTH');
    if (status == 411) {
      return const IotdbException(
        '结果集行数超过服务端限制（row_limit），请使用 LIMIT/OFFSET 分页查询',
        statusCode: 411,
        kind: 'ROW_LIMIT',
      );
    }
    final body = e.response?.data;
    String message = 'HTTP $status';
    if (body is Map<String, dynamic>) {
      message = body['message']?.toString() ?? body['error']?.toString() ?? message;
    } else if (body is String && body.isNotEmpty) {
      message = body;
    }
    return IotdbException(message, statusCode: status, kind: 'SERVER');
  }
}
