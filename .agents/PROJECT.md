# Project: Audio Progress Bar Suite & Dynamic Theming (三种音频进度条重塑与底栏等比放大)

## Architecture
- **前端架构**：Flutter / Dart 桌面端音乐播放器
- **底栏播控子系统 (`lib/component/bottom_player_bar.dart`, `lib/theme/app_theme.dart`)**：
  - `dockHeight` 统一升级为 `108.0px`，`MainLayoutFrame` 底部避让 `dockInset` 自动自适应扩大为 `108 + shellGap * 2`（零遮挡、保留标准悬浮间隙）；
  - `_BottomBarCenterSection` 进度条交互区域由 20px 提升至 `30.0px`（dense 模式为 20.0px），间距舒展扩大至 4.0px；
  - 两端已播与总时长时间文本外层容器扩宽至 `62.0px`（在 MiSans Medium w500 14px 下留有 3.54px 裕量，彻底杜绝 >1h 及 99:59:59 格式省略截断），字号放大至 `14.0px`，字重加粗为 `FontWeight.w500`。
- **进度条子系统 (`lib/component/`)**：
  - **方案一 (Fluid Laser Beam Slider)**：`FluidGlowProgressSlider`。未悬停常态平直无圆圈凸起，基准有效粗细提至 5.5px，播放头处绘制 2.5px 纯白高亮光核（Focus Core），并向左投射一段自适应衰减流光束（Beam/Comet Trail，长 64px，5 段非线性渐变 0.0->0.95 白光电光）；悬停态 180ms 平滑展开至 7.5px 浮现 6.5px 双层发光 Thumb 与 12px 毛玻璃时间气泡（`Stack(clipBehavior: Clip.none)` 悬空 0 溢出）；保留滚轮 5 秒微调与 40ms 防抖。
  - **方案二 (Adaptive Waveform Rhythm Slider)**：`AdaptiveWaveformSlider`。接入底栏 `playback.audioSpectrum` 与 `spectrumActive`；采用【复合行波与能量谐振场】模型（512-LUT 乐曲特征基底 + Bass 重低音冲程 + 空间行波微澜 + 播放头光斑激发）；一阶阻尼低通滤波与频谱解算彻底迁移入 `AnimatedBuilder.builder` 内部，音频暂停时借助比例衰减与 -0.04 线性底垫，在 183ms（<200ms）内精准平滑衰减归零，并正确触发 `_rhythmController.stop()`，彻底消除 60fps Ticker 调度泄漏；`_AdaptiveWaveformPainter` 声明 `static final Paint` 零 GC；保持全宽严丝合缝对齐几何公式 $w = W / [N + k(N-1)]$ 与 SpringSimulation 欠阻尼果冻回弹。
  - **方案三 (Dual-Layer Ambient Aurora Slider)**：`DualLayerRhythmSlider`。双层解耦架构，顶层纯时间域线性控制轨（常态 5.0px、悬停 7.0px、拖拽 8.5px，滑块 7.5~9.5px）；底层四阶极光径向光雾（$R_x=54\sim 100\text{px}, R_y=18\sim 34\text{px}$，高斯模糊 14px）与双层平滑微波（主波振幅 5~15px，次波 3.5~11px，32 段正弦平滑拟合 + 发光光织描边）；独立 `RepaintBoundary` 重绘隔离。

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1: 底栏整体扩容与等比例放大 | dockHeight 提升至 108px，MainLayoutFrame 避让联动，进度条容器提至 30px，时间字号放大至 14px w500 且 62px 容器防截断 | M2 | ORIGINAL_REQUEST §R1 |
| 2 | R2: 方案一（流体激光）强光束重塑 | 常态平直无圆圈凸起，播放头焦点纯白光核，向左 64px 彗星衰减强光束；悬停展开浮现发光 Thumb 与时间气泡 | M2 | ORIGINAL_REQUEST §R2 |
| 3 | R3: 方案二（动态声波）实时音频律动 | 接入 playback.audioSpectrum，复合行波与谐振场起伏律动，200ms 内平滑归零且停机，类级 static final Paint 60fps 零 GC | M2 | ORIGINAL_REQUEST §R3 |
| 4 | R4: 方案三（灵动呼吸）光雾视觉强化 | 四阶极光径向光雾（模糊 14px，Ry 18~34px），32 段微波光织，加粗主轨与晶体滑块，通透极光呼吸律动 | M2 | ORIGINAL_REQUEST §R4 |
| 5 | R5: 自动化测试与工程一致性 | 更新底栏与进度条尺寸变动影响的旧测试，新增光束、声波律动数据流及停机校验自动化测试，analyze 0 issues，全工程 954 测试 100% 通过 | M2 | ORIGINAL_REQUEST §R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 0 | M1: 探索与现状差距分析 | 3 名 Explorer 深度勘测 R1~R5 并形成完整技术规格 | none | DONE |
| 1 | M2: 代码重塑与整改实施 | Worker 实施底栏扩容、三种进度条重塑及缺陷闭环 | M1 | DONE |
| 2 | M3: 严格多维对抗审查与合规审计 | 2 名 Reviewer、2 名 Challenger、1 名 Forensic Auditor 全票通过 | M2 | DONE |
| 3 | M4: 门禁裁决与向父级交付汇报 | 聚合门禁判定并向 Sentinel / parent 汇报成果 | M3 | DONE |

## Gate Verdict
- Gate Iteration 1: FAIL (Reviewer 2 REQUEST_CHANGES & Challenger 1 REJECT)
- Gate Iteration 2: **PASS** (Reviewer 1 APPROVE, Reviewer 2 APPROVE, Challenger 1 APPROVE, Challenger 2 APPROVE, Forensic Auditor CLEAN)
