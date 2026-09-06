## 2026-09-01T09:22:13Z

你被指派为本项目的 E2E Test Writer（端到端测试套件构建专家）。

工作目录：e:\PyCharmSave\qisheng_player\.agents\test_writer_e2e
用户原始需求文件：e:\PyCharmSave\qisheng_player\.agents\ORIGINAL_REQUEST.md
全局项目文档：e:\PyCharmSave\qisheng_player\PROJECT.md
项目根目录：e:\PyCharmSave\qisheng_player

【独占文件写入权限】：
- `TEST_INFRA.md`（项目根目录）
- `TEST_READY.md`（项目根目录）
- `test/e2e/` 目录下的所有端到端测试用例文件

【核心任务】：
1. 建立 `TEST_INFRA.md`，基于 `PROJECT.md § Feature Inventory` 中枚举的 11 项特性，制定 4-Tier 测试架构：
   - Tier 1: Feature Coverage (每特性 ≥5 个隔离独立测试用例)
   - Tier 2: Boundary & Corner Cases (每特性 ≥5 个边界与极端场景测试用例)
   - Tier 3: Cross-Feature Combinations (主要特性成对组合交叉测试)
   - Tier 4: Real-World Application Scenarios (端到端真实用户播放、切换、最大化、详情页进退场综合旅程)
2. 在 `test/e2e/` 目录下编写高质量、严谨的 Dart/Flutter 测试用例文件，覆盖以上 4 个 Tier。
3. 运行 `flutter test test/e2e/` 及 `flutter analyze`，确保测试用例语法严格合规、逻辑自洽无报错。
4. 测试套件完整建立后，在项目根目录生成 `TEST_READY.md`（包含运行命令、各 Tier 统计与特性对照表）。
5. 在工作目录下撰写 `handoff.md` 并向父级发送汇报消息。

【MANDATORY INTEGRITY WARNING】：
DO NOT CHEAT. All test cases must be genuine and execute real assertions against the application components and contracts. DO NOT write fake tests or trivial pass-throughs. A teamwork_preview_auditor will independently verify your work.
