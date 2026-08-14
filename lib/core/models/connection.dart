class Connection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final bool enableSSL;
  final int timeoutMs;
  final int? rowLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Connection({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.enableSSL,
    required this.timeoutMs,
    this.rowLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  String get baseUrl => '${enableSSL ? 'https' : 'http'}://$host:$port';

  Connection copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? enableSSL,
    int? timeoutMs,
    int? Function()? rowLimit,
    DateTime? updatedAt,
  }) {
    return Connection(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      enableSSL: enableSSL ?? this.enableSSL,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      rowLimit: rowLimit != null ? rowLimit() : this.rowLimit,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 持久化 JSON：不含明文密码（密码单独存 Keychain，key = `conn_pwd_<id>`）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'enableSSL': enableSSL,
      'timeoutMs': timeoutMs,
      'rowLimit': rowLimit,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      password: '',
      enableSSL: json['enableSSL'] as bool? ?? false,
      timeoutMs: json['timeoutMs'] as int? ?? 30000,
      rowLimit: json['rowLimit'] as int?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAt'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['updatedAt'] as int? ?? 0,
      ),
    );
  }

  /// 供连接测试/表单使用的完整快照（含密码）
  Map<String, dynamic> toRuntimeJson() => {...toJson(), 'password': password};
}
