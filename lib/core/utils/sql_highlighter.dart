import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

/// IoTDB SQL 语法高亮（纯 Dart，单遍正则扫描）
class SqlHighlighter extends SyntaxHighlighter {
  static const Color _keywordColor = Color(0xFF0052D9);
  static const Color _stringColor = Color(0xFF2E7D32);
  static const Color _numberColor = Color(0xFFB25E00);
  static const Color _commentColor = Color(0xFF8A8F99);
  static const Color _functionColor = Color(0xFF7B1FA2);
  static const Color _pathColor = Color(0xFF00695C);

  static const Set<String> _keywords = {
    'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'INSERT', 'INTO', 'VALUES',
    'CREATE', 'DATABASE', 'DATABASES', 'TIMESERIES', 'TIMESERIES2', 'WITH',
    'TTL', 'SET', 'UNSET', 'TO', 'DROP', 'DELETE', 'SHOW', 'DESCRIBE', 'DESC',
    'EXPLAIN', 'LOAD', 'ALTER', 'RENAME', 'GRANT', 'REVOKE', 'USER', 'USERS',
    'ROLE', 'ROLES', 'PRIVILEGE', 'PRIVILEGES', 'LIST', 'LIMIT', 'OFFSET',
    'GROUP', 'BY', 'ORDER', 'ASC', 'DESCENDING', 'COUNT', 'SUM', 'AVG', 'MIN',
    'MAX', 'FIRST_VALUE', 'LAST_VALUE', 'CAST', 'AS', 'USING', 'FILL',
    'PREVIOUS', 'LINEAR', 'CONSTANT', 'SLIDING', 'INTERVAL', 'EVERY',
    'ALIGNED', 'UNALIGNED', 'DEVICE', 'DEVICES', 'TAGS', 'ATTRIBUTES',
    'ENCODING', 'COMPRESSOR', 'DATATYPE', 'BOOLEAN', 'INT32', 'INT64',
    'FLOAT', 'DOUBLE', 'TEXT', 'BLOB', 'TIMESTAMP', 'DATE', 'STRING',
    'SNAPPY', 'GZIP', 'LZ4', 'ZSTD', 'UNCOMPRESSED', 'PLAIN', 'RLE',
    'TS_2DIFF', 'GORILLA', 'DICTIONARY', 'FREQ', 'ZIGZAG', 'REGULAR', 'INF',
    'TRUE', 'FALSE', 'NULL', 'ROOT', 'SYSTEM', 'SECURITY', 'MAINTAIN',
    'USE_UDF', 'USE_PIPE', 'USE_CQ', 'USE_TRIGGER', 'USE_MODEL',
    'READ_DATA', 'WRITE_DATA', 'READ_SCHEMA', 'WRITE_SCHEMA', 'ALL',
    'GRANT_OPTION', 'DETAILS', 'VERSION', 'QUOTA', 'TABLES', 'VIEW', 'VIEWS',
    'INDEX', 'WATERMARK', 'EMBEDDED', 'ON', 'IN', 'IS', 'EXISTS', 'BETWEEN',
    'LIKE', 'INTO', 'NEW', 'OLD', 'PIPE', 'PIPES', 'PLUGIN', 'PLUGINS',
    'CQ', 'TRIGGER', 'TRIGGERS', 'MODEL', 'MODELS', 'PREPARE', 'PROCESSOR',
  };

  static final RegExp _pattern = RegExp(
    r"('(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"|--[^\n]*|/\*[\s\S]*?\*/|"
    r'\d+(?:\.\d+)?|(\b[A-Za-z_][A-Za-z0-9_.]*\b)|(\s+))',
    multiLine: true,
  );

  @override
  TextSpan format(String source) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final match in _pattern.allMatches(source)) {
      if (match.start > last) {
        spans.add(TextSpan(text: source.substring(last, match.start)));
      }
      final text = match.group(0)!;
      final token = match.group(1) ?? match.group(2) ?? '';
      if (text.startsWith("'") || text.startsWith('"')) {
        spans.add(TextSpan(text: text, style: const TextStyle(color: _stringColor)));
      } else if (text.startsWith('--') || text.startsWith('/*')) {
        spans.add(TextSpan(
          text: text,
          style: TextStyle(color: _commentColor, fontStyle: FontStyle.italic),
        ));
      } else if (RegExp(r'^\d').hasMatch(text)) {
        spans.add(TextSpan(text: text, style: const TextStyle(color: _numberColor)));
      } else if (token.isNotEmpty) {
        spans.add(_styleWord(token, source, match));
      }
      last = match.end;
    }
    if (last < source.length) {
      spans.add(TextSpan(text: source.substring(last)));
    }
    return TextSpan(style: const TextStyle(color: Color(0xFF1F2329)), children: spans);
  }

  TextSpan _styleWord(String token, String source, Match match) {
    final upper = token.toUpperCase();
    if (_keywords.contains(upper)) {
      return TextSpan(text: token, style: const TextStyle(color: _keywordColor, fontWeight: FontWeight.w500));
    }
    if (token.startsWith('root.')) {
      return TextSpan(text: token, style: const TextStyle(color: _pathColor));
    }
    final after = match.end < source.length ? source[match.end] : '';
    if (after == '(') {
      return TextSpan(text: token, style: const TextStyle(color: _functionColor, fontWeight: FontWeight.w500));
    }
    return TextSpan(text: token);
  }
}
