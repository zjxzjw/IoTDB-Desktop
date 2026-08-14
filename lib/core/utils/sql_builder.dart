/// IoTDB 2.0.10 DDL 语句拼接工具
///
/// 建库参数仅支持 2.0.10 实测的四种：
/// TTL / TIME_PARTITION_INTERVAL / SCHEMA_REGION_GROUP_NUM / DATA_REGION_GROUP_NUM
class SqlBuilder {
  SqlBuilder._();

  /// 建库：CREATE DATABASE `<db>` [WITH TTL=..., TIME_PARTITION_INTERVAL=..., ...]
  static String createDatabase(
    String name, {
    int? ttlMs,
    int? timePartitionIntervalMs,
    int? schemaRegionGroupNum,
    int? dataRegionGroupNum,
  }) {
    final withs = <String>[
      if (ttlMs != null) 'TTL=$ttlMs',
      if (timePartitionIntervalMs != null)
        'TIME_PARTITION_INTERVAL=$timePartitionIntervalMs',
      if (schemaRegionGroupNum != null)
        'SCHEMA_REGION_GROUP_NUM=$schemaRegionGroupNum',
      if (dataRegionGroupNum != null)
        'DATA_REGION_GROUP_NUM=$dataRegionGroupNum',
    ];
    final suffix = withs.isEmpty ? '' : ' WITH ${withs.join(', ')}';
    return 'CREATE DATABASE $name$suffix';
  }

  /// 删库：DROP DATABASE `<db>`
  static String dropDatabase(String name) => 'DROP DATABASE $name';

  /// 设置 TTL：SET TTL TO `<db>` <毫秒|INF>
  static String setTtl(String db, {int? ttlMs}) {
    final value = ttlMs == null ? 'INF' : '$ttlMs';
    return 'SET TTL TO $db $value';
  }

  /// 取消 TTL：UNSET TTL TO `<db>`
  static String unsetTtl(String db) => 'UNSET TTL TO $db';

  /// 建测点：CREATE TIMESERIES `<path>` WITH DATATYPE=...[, ENCODING=...][, COMPRESSOR=...]
  /// [TAGS(...)] [ATTRIBUTES(...)]，tags/attributes 为 key=value 列表
  static String createTimeseries(
    String path, {
    required String dataType,
    String? encoding,
    String? compressor,
    Map<String, String>? tags,
    Map<String, String>? attributes,
  }) {
    final withs = <String>['DATATYPE=$dataType'];
    if (encoding != null && encoding.trim().isNotEmpty) {
      withs.add('ENCODING=${encoding.trim().toUpperCase()}');
    }
    if (compressor != null && compressor.trim().isNotEmpty) {
      withs.add('COMPRESSOR=${compressor.trim().toUpperCase()}');
    }
    final buffer = StringBuffer(
      'CREATE TIMESERIES $path WITH ${withs.join(', ')}',
    );
    if (tags != null && tags.isNotEmpty) {
      buffer.write(' TAGS(${_kvList(tags)})');
    }
    if (attributes != null && attributes.isNotEmpty) {
      buffer.write(' ATTRIBUTES(${_kvList(attributes)})');
    }
    return buffer.toString();
  }

  /// 删除测点：DELETE TIMESERIES `<path>`[, `<path>`...]
  static String deleteTimeseries(List<String> paths) =>
      'DELETE TIMESERIES ${paths.join(', ')}';

  static String _kvList(Map<String, String> map) {
    return map.entries.map((e) => '${e.key}=${_quote(e.value)}').join(', ');
  }

  /// 值含特殊字符/空格时加单引号
  static String _quote(String v) {
    final needsQuote =
        v.isEmpty || RegExp(r"[\s,=()'\u4e00-\u9fa5]").hasMatch(v);
    if (!needsQuote) return v;
    return "'${v.replaceAll("'", "\\'")}'";
  }
}
