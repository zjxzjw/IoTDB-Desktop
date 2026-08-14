# IoTDB Desktop（Flutter 版）开发计划

> 目标：用 Flutter 从零开发 IoTDB 桌面管理工具（macOS 优先，架构兼容 Windows/Linux），
> 对接服务器 `106.55.231.32:18080`（IoTDB 2.0.10，REST v2，Basic 鉴权）。
> 功能：多连接管理、数据库管理、SQL 工作台、用户与权限管理、数据浏览与图表。

## 1. 技术选型与关键决策

| 领域 | 方案 |
|---|---|
| 框架 | Flutter 3.38.7 (stable)，模板项目已就绪 |
| 平台 | macOS 优先（验证编译），保留 windows/linux 目录 |
| 状态管理 | `flutter_riverpod ^2.x` |
| 路由 | `go_router` |
| HTTP | `dio`（baseUrl + 拦截器注入 Basic Auth + 超时） |
| 密码存储 | `flutter_secure_storage`（macOS Keychain） |
| 配置持久化 | `path_provider` → Application Support/connections.json（密码脱敏存 Keychain） |
| SQL 编辑器 | `code_text_field ^1.1.x` + 自定义 IoTDB SQL SyntaxHighlighter（纯 Dart，不用 Monaco） |
| 图表 | `fl_chart`（替代 ECharts） |
| 图标 | `remixicon ^4.9.3`（RemixIcon 全库 3200+，Outline 为主） |
| UI | Material 3 组件 + TDesign 设计令牌 |
| 工具 | `uuid`、`intl` |

### 实测协议要点（服务器 2.0.10 已验证）

- `GET /ping`：检活，无鉴权
- `POST /rest/v2/query`：body `{sql, row_limit?}`，数据与元数据查询
- `POST /rest/v2/nonQuery`：body `{sql}`，DDL/DML
- 鉴权：`Authorization: Basic base64(user:pass)`
- 结果集格式：`{column_names[], values[列主序], timestamps?, data_types?}`（列主序：values[列][行]）
- HTTP 401 = 认证失败；HTTP 411 = 行数超 row_limit → UI 用 LIMIT/OFFSET 分页兜底
- SQL 路由启发式：`SELECT/SHOW/COUNT/LIST/DESCRIBE/DESC/EXPLAIN/LOAD` → query，其余 → nonQuery

### 2.0.10 语法适配（已验证）

- 建库参数仅支持：`TTL / TIME_PARTITION_INTERVAL / SCHEMA_REGION_GROUP_NUM / DATA_REGION_GROUP_NUM`（不支持 schema/data 副本因子）
- TTL：`SET TTL TO <db> <毫秒|INF>`、`UNSET TTL TO <db>`
- 权限新命名：全局 `SYSTEM/SECURITY/MAINTAIN/USE_UDF/USE_PIPE/USE_CQ/USE_TRIGGER/USE_MODEL` + 路径权限 `READ_DATA/WRITE_DATA/READ_SCHEMA/WRITE_SCHEMA`，支持 `ALL` 与 `WITH GRANT OPTION`
- 元数据：`SHOW DATABASES DETAILS`（无 TTL 列）、`SHOW DEVICES <db>.** WITH DATABASE`（⚠️ 必须带 `.**` 通配，不带返回空）、`SHOW TIMESERIES <path>.**`（11 列含 Tags/Attributes）
- ⚠️ SELECT 类响应用 `expressions` 字段而非 `column_names`（QueryResult.fromRestJson 已兜底）；SHOW 类用 `column_names`

## 2. 设计系统（TDesign 价值观 → Material 3 令牌）

- 品牌价值观：包容、多元、进化、连接；克制清晰的视觉语言
- 主色 `#0052D9`（hover `#2667D4`、focus 10% 透明、disabled `#B8CBE8`）
- 功能色：成功 `#00A870` / 警告 `#ED7B2F` / 危险 `#D54941`
- 中性色：主文字 rgba(0,0,0,.9) / 次要 .6 / 占位 .4 / 禁用 .26；边框 rgba(0,0,0,.15)、分隔 .06；页面底 `#F6F6F6`、容器白、hover 4% 黑
- 圆角：small 3 / default 6 / medium 9 / large 12 / xl 24
- 字号：12 辅助 / 14 正文 / 16 卡片标题 / 20 页面标题；字重 400/500/600
- 间距：4px 栅格（4/8/12/16/24/32）；轻量阴影分层
- 深色模式为 M6 增强项（令牌双套）

## 3. 架构

```
lib/
├── main.dart / app.dart            # 入口 + MaterialApp + go_router + Theme
├── core/
│   ├── theme/    tdesign_tokens.dart、app_theme.dart（light/dark）
│   ├── network/  iotdb_client.dart（dio 封装：ping/query/nonQuery、错误→中文映射）、
│   │             statement_router.dart（query/nonQuery 判定）
│   ├── storage/  connection_store.dart、secure_store.dart
│   ├── models/   connection.dart、query_result.dart 等
│   └── utils/    sql_builder.dart、format.dart、error_messages.dart
├── features/
│   ├── connections/  连接侧边栏 + 连接管理页 + 新建/编辑表单
│   ├── workspace/    工作区容器（连接信息 + Tab 导航）
│   ├── database/     数据库管理页、建库/TTL/建测点表单、元数据树（递归+懒加载）、测点详情
│   ├── sql/          SQL 工作台：编辑器、高亮、补全、结果表格、历史
│   ├── users/        用户/角色/权限编辑器
│   └── data/         数据浏览 + fl_chart 折线图
└── shared/           status_dot、confirm_dialog、empty_state、paged_table
```

## 4. 里程碑

| 阶段 | 内容 | 验收 |
|---|---|---|
| M0 工程与设计系统 | 依赖接入；TDesign 令牌→Material3 主题；RemixIcon；**macOS entitlements 加 `com.apple.security.network.client`**；三栏布局骨架；go_router + Riverpod | `flutter run -d macos` 出界面 ✅ |
| M1 连接管理 | IotdbClient（ping/query/nonQuery/超时/错误映射）；ConnectionStore（JSON+Keychain）；连接 CRUD+测试+状态+打开工作区 | 真实服务器建连/测试/持久化闭环 ✅（SecureStore 用文件兜底，Keychain 因 ad-hoc 签名弃用） |
| M2 数据库管理 | SHOW DATABASES DETAILS 表格；建库表单（2.0.10 参数裁剪）；TTL；元数据树（库→设备→测点懒加载）；测点建/删/详情 | 建库→建测点→浏览→TTL→删除全流程 ✅（tool/verify_m2.dart 16 项实测通过） |
| M3 SQL 工作台 | code_text_field 多标签；IoTDB 高亮+补全（关键字+动态测点）；语句路由；结果表格（分页/类型）；历史；Cmd/Ctrl+Enter | 任意 SQL 正确执行渲染 |
| M4 用户与权限 | 用户/角色 CRUD；可视化权限编辑器（新命名+路径+grant option+ALL）；LIST PRIVILEGES | 建用户→授权→验证闭环 |
| M5 数据浏览 | 测点分页预览（复用结果表格）；fl_chart 折线图（聚合+GROUP BY 时间窗） | 数据可视化正确 |
| M6 收尾 | 深色模式；统一错误处理；应用图标；`flutter build macos` 打包 | 可分发 dmg |

## 5. 风险与对策

- macOS 沙箱网络：entitlements 缺 `network.client` → M0 内解决
- code_text_field 高亮性能：分段高亮 + 编辑节流
- 大结果集：row_limit + 411 处理 → LIMIT/OFFSET 分页
- 1.x/2.x SQL 差异：面向 2.0.10，适配层预留扩展点
- Keychain 首次访问弹窗：测试连接时预期行为，UI 提示

## 6. 目录说明

- Flutter 项目：`iotdb_desktop/`（本计划所在）
- Electron 旧代码：`iotdb-desktop/` 顶层，保留不动
