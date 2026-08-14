# IoTDB Desktop 交接计划

> 更新时间：2026-08-14。供后续开发会话快速接续，细节以 PLAN.md 为准。

## 当前进度

| 阶段 | 状态 | 说明 |
|---|---|---|
| M0 工程与设计系统 | ✅ 完成 | TdTokens/app_theme、RemixIcon、双主题、entitlements 已配 |
| M1 连接管理 | ✅ 完成 | 连接 CRUD/测试/持久化，工作区占位 |
| M2 数据库管理 | ✅ 完成 | 16 项端到端实测通过（tool/verify_m2.dart） |
| M3 SQL 工作台 | 🟡 代码完成 | 多标签/高亮/补全/路由/历史/快捷键；analyze+test 通过，**待真实服务器验证** |
| M4 用户与权限 | ⬜ 未开始 | |
| M5 数据浏览 | ⬜ 未开始 | |
| M6 收尾 | ⬜ 未开始 | 深色切换/图标/打包 |

## 目录与职责

```
lib/
├── core/
│   ├── network/    iotdb_client（dio+Basic Auth+错误映射）、statement_router（query/nonQuery 判定）
│   ├── models/     connection、query_result（列主序解析，SELECT 用 expressions 兜底）
│   ├── storage/    connection_store（connections.json）、secure_store（⚠️文件兜底，非 Keychain）
│   ├── theme/      tdesign_tokens、app_theme
│   ├── utils/      sql_builder（DDL 拼接）、sql_highlighter（patternMap/stringMap）
│   └── providers.dart（连接/客户端/数据库列表 provider）
├── features/
│   ├── connections/    侧边栏 + 连接表单
│   ├── home/           home_shell（侧边栏 + WorkspaceScreen Tab 容器）
│   ├── database/       data/database_providers、presentation/数据库页+元数据树+建库/TTL/建测点表单
│   └── sql/            data/sql_history_provider、presentation/工作台+编辑器+结果面板
├── shared/            result_table（分页表格）、confirm_dialog、empty_state、status_dot
tool/verify_m2.dart   端到端验证脚本（IOTDB_PASSWORD=xxx dart run tool/verify_m2.dart）
```

## 已验证的服务器要点（2.0.10，勿再踩坑）

- 服务器 `106.55.231.32:18080`，账号 root/root（用户提供的密码）
- `SHOW DEVICES <db>` 不带 `.**` 返回**空**，必须 `SHOW DEVICES <db>.** WITH DATABASE`
- SELECT 响应无 `column_names`，用 `expressions`（QueryResult.fromRestJson 已兜底）
- `SHOW DATABASES DETAILS` 无 TTL 列；TTL 用 `SET/UNSET TTL TO <db> <毫秒|INF>`
- 建库仅 4 参数：TTL / TIME_PARTITION_INTERVAL / SCHEMA_REGION_GROUP_NUM / DATA_REGION_GROUP_NUM
- 权限新命名见 PLAN.md（M4 用）

## 常用命令

```bash
flutter run -d macos          # 运行（正在后台跑，nohup 日志 /tmp/flutter_run.log）
flutter analyze && flutter test
IOTDB_PASSWORD=root dart run tool/verify_m2.dart   # 端到端验证（建测试库并用后清理）
flutter build macos           # 打包（M6）
```

## 下一位继续做什么

1. **M3 验证**：连接真实服务器用 SQL 工作台跑一遍（SHOW/SELECT/INSERT/DROP），确认高亮、补全、多语句、历史、Cmd+Enter 无异常；重点看 CodeField 的补全交互
2. **M4 用户与权限**：`lib/features/users/`，基于 SHOW USERS/LIST PRIVILEGES/GRANT/REVOKE；权限 SQL 走 nonQuery
3. **M5 数据浏览**：`lib/features/data/`，paged_table 复用 + fl_chart 折线图（聚合 + GROUP BY 时间窗）
4. **M6 收尾**：深色模式开关（app_theme 已有 dark 分支，需持久化偏好）、应用图标、`flutter build macos`、更新 PLAN.md 里程碑状态

## 注意事项

- 全局中文注释/文案/UI，样式一律走 TdTokens + RemixIcons，勿硬编码颜色
- Riverpod 3.x（AsyncNotifierProvider/NotifierProvider），`AsyncValue.value` 替代旧 `valueOrNull`
- code_text_field 导入名是 `package:code_text_field/code_text_field.dart`（1.1.0，非 flutter_code_editor），高亮用 patternMap/stringMap，无内置补全 API（补全是自研浮层）
- SecureStore 因 ad-hoc 签名 Keychain 报 -34018 弃用 Keychain，**勿改回**（除非有正式签名）
- 非 git 仓库，无版本控制
- 验证服务器凭据仅存于本地会话，勿写入代码/文档