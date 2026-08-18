import '../models/table_meta.dart';

/// IoTDB 2.0.x 表模型 SQL 语句拼接工具
///
/// 说明：REST 接口无会话状态（USE 不跨请求持久），所有语句一律使用
/// `"库名"."表名"` 全限定名。标识符统一加双引号，避免中文/特殊字符解析问题。
class SqlBuilder {
  SqlBuilder._();

  /// 标识符加双引号（`"` 转义为 `""`）
  static String ident(String name) => '"${name.replaceAll('"', '""')}"';

  /// 库表全限定名："db"."table"
  static String qualified(String db, String table) =>
      '${ident(db)}.${ident(table)}';

  /// 列定义段：`"name" TYPE CATEGORY [COMMENT '...']`
  static String columnDef(TableColumn c) {
    final buf = StringBuffer(
      '${ident(c.name)} ${c.dataType} ${c.category.sqlKeyword}',
    );
    if (c.comment != null && c.comment!.trim().isNotEmpty) {
      buf.write(" COMMENT '${_escapeSql(c.comment!)}'");
    }
    return buf.toString();
  }

  /// 建库：CREATE DATABASE "db" [WITH (TTL=..., TIME_PARTITION_INTERVAL=..., ...)]
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
    final suffix = withs.isEmpty ? '' : ' WITH (${withs.join(', ')})';
    return 'CREATE DATABASE ${ident(name)}$suffix';
  }

  /// 删库：DROP DATABASE "db"
  static String dropDatabase(String name) => 'DROP DATABASE ${ident(name)}';

  /// 设置数据库 TTL：`ALTER DATABASE "db" SET PROPERTIES TTL=<ms|INF>`
  static String alterDatabaseTtl(String db, {int? ttlMs}) {
    final value = ttlMs == null ? 'INF' : '$ttlMs';
    return 'ALTER DATABASE ${ident(db)} SET PROPERTIES TTL=$value';
  }

  /// 建表：CREATE TABLE [IF NOT EXISTS] "db"."t" ("col" TYPE CATEGORY, ...)
  /// [COMMENT '...'] [WITH (TTL=...)]
  /// 未显式定义时间列时自动补 `time TIMESTAMP TIME`
  static String createTable(
    String db,
    String table, {
    required List<TableColumn> columns,
    String? comment,
    int? ttlMs,
    bool ifNotExists = false,
  }) {
    var defs = columns.map(columnDef).toList();
    final hasTime = columns.any((c) => c.category == ColumnCategory.time);
    if (!hasTime) {
      defs = [
        '${ident('time')} TIMESTAMP TIME',
        ...defs,
      ];
    }
    final ifne = ifNotExists ? ' IF NOT EXISTS' : '';
    final buf = StringBuffer(
      'CREATE TABLE$ifne ${qualified(db, table)} (${defs.join(', ')})',
    );
    if (comment != null && comment.trim().isNotEmpty) {
      buf.write(" COMMENT '${_escapeSql(comment)}'");
    }
    if (ttlMs != null) buf.write(' WITH (TTL=$ttlMs)');
    return buf.toString();
  }

  /// 删表：DROP TABLE IF EXISTS "db"."t"
  static String dropTable(String db, String table, {bool ifExists = true}) {
    final fe = ifExists ? ' IF EXISTS' : '';
    return 'DROP TABLE$fe ${qualified(db, table)}';
  }

  /// 加列：`ALTER TABLE "db"."t" ADD COLUMN IF NOT EXISTS <colDef>`
  static String alterAddColumn(String db, String table, TableColumn column) =>
      'ALTER TABLE ${qualified(db, table)} ADD COLUMN IF NOT EXISTS ${columnDef(column)}';

  /// 删列：ALTER TABLE "db"."t" DROP COLUMN IF EXISTS "col"
  /// 注：仅 FIELD / ATTRIBUTE 列可删除
  static String alterDropColumn(String db, String table, String column) =>
      'ALTER TABLE ${qualified(db, table)} DROP COLUMN IF EXISTS ${ident(column)}';

  /// 设置表 TTL：`ALTER TABLE "db"."t" SET PROPERTIES TTL=<ms|INF|default>`
  /// [ttlMs] 为空表示 INF（永久）；[useDefault] 为 true 时恢复为数据库默认 TTL
  static String alterTableTtl(
    String db,
    String table, {
    int? ttlMs,
    bool useDefault = false,
  }) {
    final value = useDefault ? 'default' : (ttlMs == null ? 'INF' : '$ttlMs');
    return 'ALTER TABLE ${qualified(db, table)} SET PROPERTIES TTL=$value';
  }

  static String _escapeSql(String v) => v.replaceAll("'", "''");

  /// 数据浏览查询：按时间列倒序取最近 [limit] 条记录
  /// `SELECT * FROM "db"."table" ORDER BY "time" DESC LIMIT <limit>`
  static String browseLatest(
    String db,
    String table, {
    int limit = 100,
    String timeColumn = 'time',
  }) =>
      'SELECT * FROM ${qualified(db, table)} '
      'ORDER BY ${ident(timeColumn)} DESC LIMIT $limit';
}
