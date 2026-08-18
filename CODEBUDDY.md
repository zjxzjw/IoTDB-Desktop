# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

## 常用命令

```bash
# 安装依赖
flutter pub get

# 运行（macOS 桌面端）
flutter run -d macos

# 静态检查
flutter analyze

# 全部测试
flutter test

# 单个测试文件
flutter test test/unit/sql_builder_test.dart

# 单个用例（按名称过滤）
flutter test test/unit/statement_router_test.dart --plain-name "routes SELECT to query"
```

代码风格与静态分析由 `analysis_options.yaml`（基于 `flutter_lints`）约束，改动后请确保 `flutter analyze` 无新增告警。

## 项目概述

IoTDB Desktop 是一个 Flutter 桌面应用（macOS + Windows），作为 Apache IoTDB 2.x **表模型（Table Model）** 的图形化管理客户端。它通过 IoTDB 的 **REST v2 接口**（`/rest/table/v1/query` 与 `/rest/table/v1/nonQuery`）与服务器通信，没有直接依赖 JDBC/Thrift 或 IoTDB 原生 SDK。应用界面为中文。

## 高层架构

### 目录结构

```
lib/
├── main.dart                 # 入口：ProviderScope + IotdbDesktopApp
├── app.dart                  # MaterialApp，主题/明暗模式
├── core/
│   ├── models/               # Connection、QueryResult、TableMeta 等纯数据模型
│   ├── network/              # IotdbClient（dio 封装）、StatementRouter（SQL 路由）
│   ├── storage/              # connections.json / secrets.json / settings.json 持久化
│   ├── theme/                # shadcn 设计令牌 + buildAppTheme
│   ├── utils/                # SqlBuilder（SQL 语句拼接）
│   └── providers.dart        # 全局共享状态（连接、活动连接、页面导航等）
├── features/
│   ├── connections/          # 连接管理：侧边栏树 + 新建/编辑表单
│   ├── home/                 # HomeShell（整体外壳）与 WorkspaceScreen（5 页面切换）
│   ├── dashboard/            # 仪表盘：版本、表总数、集群信息、延迟
│   ├── sql/                  # SQL 工作台：re_editor 编辑器 + 结果表格
│   ├── database/             # 表管理：建/删库表、列管理与 TTL
│   ├── users/                # 用户与权限：用户/角色/授权管理
│   └── data/                 # 数据浏览：查询、分页、fl_chart 折线图
└── shared/                   # 跨 feature 复用的通用小部件（如确认对话框）
```

每个 feature 内部再按 `presentation/`（Widget）与 `data/`（Riverpod Provider）分层。测试位于 `test/`，分为 `unit/`、`widget/`、`storage/`、`integration/`，公共辅助代码在 `test/helpers/`。

### 状态管理：flutter_riverpod 3.x

全局 provider 集中在 `lib/core/providers.dart`，是理解数据流的关键：

- `connectionStoreProvider`（AsyncNotifier）— 连接列表，启动时从磁盘加载，增删改后同步内存与磁盘。
- `activeConnectionProvider`（Notifier）— 当前工作区打开的连接，`null` 表示回到欢迎页。
- `iotdbClientProvider` — 随 `activeConnection` 重建的 `IotdbClient`；feature 层的业务 provider 都依赖它发请求。
- `databaseListProvider` / `connectionDatabaseListProvider` — 数据库列表。后者是 `FutureProvider.family<QueryResult, Connection>`，按连接独立缓存，使侧边栏可同时展开多个连接的数据库树。
- `databaseSelectionProvider` / `tableSelectionProvider` — 侧栏与表管理页共享的选中状态。
- `workspacePageProvider` — `WorkspaceScreen` 当前页（dashboard/sql/tables/users/data）。
- `sidebarWidthProvider` / `themeModeProvider` — 持久化的 UI 偏好。

feature 级 provider 放在各 feature 的 `data/` 目录（如 `sql_workbench_provider.dart`、`database_providers.dart`、`data_providers.dart`、`users_providers.dart`、`dashboard_providers.dart`）。SQL 工作台的会话状态（编辑器文本/结果/分割比例）是 per-connection 且**非 autoDispose**，切换页面不丢失内容。

### 网络层与 SQL 路由

`lib/core/network/iotdb_client.dart` 用 dio 实现：

- 构造时从 `Connection` 注入 Basic Auth（`/ping` 除外），超时取自连接配置。
- `query()` → `POST /rest/table/v1/query`，解析 REST JSON 为 `QueryResult`，支持 `row_limit`。
- `nonQuery()` → `POST /rest/table/v1/nonQuery`，用于 DDL/DML/权限语句。
- REST v2 的 SQL 错误以 HTTP 200 + `{code: !=200, message}` 返回，`_throwIfServerError` 显式抛出。
- 所有异常归一为 `IotdbException`，带 `kind`（TIMEOUT / CONNECTION / AUTH / ROW_LIMIT / SERVER），UI 据此展示中文提示。

`StatementRouter.isQuery(sql)` 按首词启发式决定走 query 还是 nonQuery 端点：SELECT/SHOW/COUNT/LIST/DESCRIBE/EXPLAIN/LOAD 前缀 → query，其余 → nonQuery。该路由也用于 SQL 工作台逐条拆分执行。

### SQL 生成：SqlBuilder

`lib/core/utils/sql_builder.dart` 是 DDL/DML 语句的唯一拼装入口（建库/删库/建表/删表/加删列/设置 TTL 等）。两个不可违背的约定：

1. **REST 无会话状态**：`USE` 不跨请求生效，因此所有语句一律使用 `"db"."table"` 全限定名。
2. **标识符统一加双引号**：`ident()` 用 `"` 包裹并转义内部 `"`，避免中文/特殊字符解析问题。

新增 SQL 生成逻辑必须复用 SqlBuilder，不要手写字符串拼接。

### 持久化

- `connections.json` — 连接列表（脱敏，不含密码）。
- `secrets.json` — 密码，base64 编码 + 0600 文件权限（原 Keychain 实现因 macOS 15+ ad-hoc 签名触发 -34018 已弃用，见 `SecureStore` 注释）。
- `settings.json`（`AppSettingsStore`）— 侧边栏宽度、主题模式等 UI 偏好。

均存于 `getApplicationSupportDirectory()`。加载时容忍文件损坏（重置为空，不影响启动）。

### UI 与主题

遵循 shadcn/ui 风格设计令牌（`lib/core/theme/shadcn_tokens.dart`，zinc 色板），`buildAppTheme` 依据令牌生成亮/暗两套 `ThemeData`，支持跟随系统。图标使用 `remixicon` 包。

### 关键页面

- `HomeShell` — 可拖拽调宽的连接侧边栏 + 右侧内容区；无活动连接时显示欢迎页。
- `WorkspaceScreen` — AppBar 用 `SegmentedButton` 切换 5 个页面，整页占据内容区。
- `SqlWorkbenchPage` — re_editor 编辑器 + 结果表格上下布局；执行时按 `;` 拆句、有选中则只执行选中部分，再经 StatementRouter 路由到 query/nonQuery。

## 测试方式

测试不发起真实网络请求，核心模式：

1. `test/helpers/fake_iotdb_client.dart` 的 `FakeIotdbClient` 继承真实客户端，记录收到的 SQL、按 SQL 注入返回 JSON 或异常。
2. `test/helpers/pump.dart` 的 `wrapWithProvider()` 用 ProviderScope override 替换 `iotdbClientProvider` 及可选的数据库/表选择、列表数据（Riverpod 3 未导出 `Override` 类型，overrides 在此内联构造）。
3. `test/helpers/path_provider_mock.dart` 提供 `mockPathProvider()`，让存储相关测试落到临时目录。
4. `enlargeSurface()` 放大测试画布，避免桌面端表单被裁剪。

新增功能时建议遵循：SQL 拼装逻辑 → `test/unit/*_test.dart` 单测；Provider 行为 → 直接驱动 notifier 或用 `wrapWithProvider` 渲染 widget 验证交互。

## 注意事项

- 不要向 `Connection` 模型加入明文密码字段，密码只经 `SecureStore` 读写。
- 新增语句路由时，`StatementRouter._queryPrefixes` 需同步确认，避免 DDL 被误路由到 query 端点。
- 代码注释与 UI 文案使用中文，保持与现状一致。
