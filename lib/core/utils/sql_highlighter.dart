import 'package:flutter/material.dart';

/// IoTDB SQL 高亮配置（code_text_field 的 patternMap/stringMap）
class SqlHighlighter {
  SqlHighlighter._();

  static const Color keywordColor = Color(0xFF0052D9);
  static const Color stringColor = Color(0xFF2E7D32);
  static const Color numberColor = Color(0xFFB25E00);
  static const Color commentColor = Color(0xFF8A8F99);
  static const Color pathColor = Color(0xFF00695C);

  /// 高亮关键字（同时供补全使用）
  static const Set<String> keywords = {
    'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'INSERT', 'INTO', 'VALUES',
    'CREATE', 'DATABASE', 'DATABASES', 'TIMESERIES', 'WITH', 'TTL', 'SET',
    'UNSET', 'TO', 'DROP', 'DELETE', 'SHOW', 'DESCRIBE', 'DESC', 'EXPLAIN',
    'LOAD', 'ALTER', 'GRANT', 'REVOKE', 'USER', 'USERS', 'ROLE', 'ROLES',
    'PRIVILEGE', 'PRIVILEGES', 'LIST', 'LIMIT', 'OFFSET', 'GROUP', 'BY',
    'ORDER', 'ASC', 'DESCENDING', 'COUNT', 'SUM', 'AVG', 'MIN', 'MAX',
    'FIRST_VALUE', 'LAST_VALUE', 'CAST', 'AS', 'USING', 'FILL', 'PREVIOUS',
    'LINEAR', 'CONSTANT', 'SLIDING', 'INTERVAL', 'EVERY', 'ALIGNED',
    'UNALIGNED', 'DEVICE', 'DEVICES', 'TAGS', 'ATTRIBUTES', 'ENCODING',
    'COMPRESSOR', 'DATATYPE', 'BOOLEAN', 'INT32', 'INT64', 'FLOAT', 'DOUBLE',
    'TEXT', 'BLOB', 'TIMESTAMP', 'DATE', 'STRING', 'SNAPPY', 'GZIP', 'LZ4',
    'ZSTD', 'UNCOMPRESSED', 'PLAIN', 'RLE', 'TS_2DIFF', 'GORILLA',
    'DICTIONARY', 'FREQ', 'ZIGZAG', 'REGULAR', 'INF', 'TRUE', 'FALSE',
    'NULL', 'ROOT', 'SYSTEM', 'SECURITY', 'MAINTAIN', 'USE_UDF', 'USE_PIPE',
    'USE_CQ', 'USE_TRIGGER', 'USE_MODEL', 'READ_DATA', 'WRITE_DATA',
    'READ_SCHEMA', 'WRITE_SCHEMA', 'ALL', 'DETAILS', 'VERSION', 'WATERMARK',
    'ON', 'IN', 'IS', 'EXISTS', 'BETWEEN', 'LIKE', 'CQ', 'TRIGGER',
    'TRIGGERS', 'MODEL', 'MODELS', 'PIPE', 'PIPES', 'PLUGIN', 'PLUGINS',
    'INDEX', 'QUOTA',
  };

  /// 正则 → 样式
  static final Map<String, TextStyle> patternMap = {
    r"'[^'\n]*'": const TextStyle(color: stringColor),
    r'"[^"\n]*"': const TextStyle(color: stringColor),
    r'(--[^\n]*|/\*[\s\S]*?\*/)':
        TextStyle(color: commentColor, fontStyle: FontStyle.italic),
    r'\b\d+(?:\.\d+)?\b': const TextStyle(color: numberColor),
    r'\broot(?:\.[\w\u4e00-\u9fa5]+)+': const TextStyle(color: pathColor),
  };

  /// 关键字 → 样式
  static final Map<String, TextStyle> stringMap = {
    for (final k in keywords) k: const TextStyle(color: keywordColor, fontWeight: FontWeight.w500),
  };
}
