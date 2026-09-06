# Orchestration Plan: Qisheng Player Transition & Layout Refactor

## 总体目标
重构播放详情页与底栏转场动效系统，彻底移除黑胶唱机模式，统一现代纯封面画册布局，对齐 Hero 动效子树与包围盒，优化淡入淡出与 Staged Reveal，平滑窗口边距过渡，并确保代码零 warning/error、测试全通过以及 60/120fps 高性能。

## 执行阶段
### 阶段 0：全面勘探调研 (Survey Phase)
- 启动 3 个并行 Explorer 对项目代码库展开多维度深入调查：
  - Explorer 1: NowPlayingPage、VinylRecordPlayerView、设置选项及所有相关黑胶唱机代码/开关/分支的引用位置。
  - Explorer 2: 底栏 PlayerBar、封面组件、Hero 动效树、包围盒（Box Constraints）、比例与裁切（ClipRRect, AspectRatio, FittedBox）机制。
  - Explorer 3: AppShell, NowPlayingShellUnderlay, MainLayoutFrame 边距动画（topInset, sideInset, shellGap 等）以及背景流光协同淡入淡出、Staged Reveal 时间轴。
- 汇总勘探结果，编制 `PROJECT.md`（包含详细 Feature Inventory、架构边界与里程碑规划）。

### 阶段 1：双轨规划与分工 (Dual Track Setup)
- 轨一（E2E Testing Track）：独立测试编排，编写覆盖各 Feature 的多层级测试用例（Tier 1-4），产出 `TEST_INFRA.md` 与 `TEST_READY.md`。
- 轨二（Implementation Track）：
  - 里程碑 1：移除黑胶唱机组件与关联设置/开关/状态。
  - 里程碑 2：统一纯封面画册布局与 Hero 子树结构重构（底栏封面与详情页封面完美几何对齐）。
  - 里程碑 3：重构协同淡入淡出与 Staged Reveal 动效（歌词、标题、控制栏等时间轴编排）。
  - 里程碑 4：MainLayoutFrame 布局边距平滑过渡（AnimatedPadding / AnimatedContainer 等）。
  - 最终里程碑：通过 100% E2E 测试及对抗性覆盖强化（Tier 5 对抗性测试、性能与静态分析零 warning/error 校验）。

### 阶段 2：里程碑推进与门禁验证 (Execution & Gate Verification)
- 每个里程碑严格按 Explorer -> Worker -> Reviewers (2) -> Challengers (2) -> Forensic Auditor 循环验证。
- 门禁严格执行全 PASS 标准及审计一票否决制。

### 阶段 3：验收与报告 (Final Report)
- 验证所有自动化测试与 flutter analyze。
- 编制全面 handoff.md 并向 Sentinel 发送最终完成报告。
