# Task R3 调研与实施方案交付报告：播放队列抽屉高斯模糊磨砂背景与弹出动效优化

## 1. Observation (直接观察事实)

### 1.1 播放队列抽屉的定位与当前实现
- **文件路径**: `e:\PyCharmSave\qisheng_player\lib\component\bottom_player_bar.dart`
- **组件类名与行号**: `_QueueEntryButton` 类（第 1249 ~ 1360 行），入口方法 `_openQueueDrawer(BuildContext context)`（第 1255 ~ 1337 行）。
- **当前抽屉结构与调用代码**:
```dart
Future<void> _openQueueDrawer(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final width = (size.width * 0.36).clamp(380.0, 520.0).toDouble();

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '播放队列',
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, anim1, anim2) {
      final scheme = Theme.of(context).colorScheme;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: width,
            height: double.infinity,
            margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: CpSurface(
              tone: CpSurfaceTone.floating,
              radius: 24,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '播放队列',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      CpIconButton(
                        variant: CpButtonVariant.immersive,
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Symbols.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Expanded(
                    child: CurrentPlaylistView(
                      showHeader: false,
                      dense: true,
                      enableReorder: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}
```

### 1.2 背景材质与模糊状态观察
- 在 `_openQueueDrawer` 中，抽屉背景包裹在 `CpSurface(tone: CpSurfaceTone.floating)` 中。
- 观察 `lib/component/cp/cp_components.dart`（第 383、457~464 行）：
  ```dart
  final applyBlur = surfaces.backdropStrategy != AppBackdropStrategy.solid;
  ...
  return ClipRRect(
    borderRadius: BorderRadius.circular(resolvedRadius),
    child: applyBlur
        ? BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: surfaces.glassSigma * _toneSigmaScale(),
              sigmaY: surfaces.glassSigma * _toneSigmaScale(),
            ),
            child: content,
          )
        : content,
  );
  ```
- 观察 `lib/theme/app_theme.dart`（第 359~364 行）：
  ```dart
  panelAlpha: 0.0,
  glassAlpha: 0.0,
  glassSigma: 0.0,
  shadowDepthScale: 0.0,
  effectsLevel: effectsLevel,
  backdropStrategy: AppBackdropStrategy.solid,
  ```
  在全局应用主题配置中，`backdropStrategy` 为 `solid`，`glassSigma` 为 `0.0`，`panelAlpha` 为 `0.0`。
  因此 `CpSurface` 内部的 `applyBlur` 计算为 `false`，**完全不会渲染 BackdropFilter**，且由于 `panelAlpha` 为 0，底色透明度极高接近完全穿透。

### 1.3 动画与交互观察
- 动画时长：`transitionDuration: const Duration(milliseconds: 280)`
- 进场曲线：`curve: Curves.easeOutCubic`
- 退场曲线：`reverseCurve: Curves.easeInCubic`
  - `Curves.easeInCubic` 具有初始加速度极小、末端加速度达到峰值的特性。在 280ms 的短时间内收起时，前段停顿、末端瞬间闪退消失（Snap off），产生明显的生硬感。
- 遮罩层：`barrierColor: Colors.black26`，为单一硬编码透明度，未随明暗主题进行精细适配。

---

## 2. Logic Chain (推导逻辑链)

1. **背景穿透与可读性冲突原因分析**：
   - 播放器在全屏沉浸式播放页（`ImmersiveNowPlayingView`）以及其他主界面上，背景存在高亮大字号滚动歌词（字号 30~36px，`_CenteredLyricView`）、动态呼吸封面和实时音频频谱。
   - 当从右下角呼出播放队列时，由于 `CpSurface` 依赖的全局主题 `backdropStrategy` 处于 `solid` 策略，导致 `BackdropFilter` 被跳过，抽屉实质上处于无高斯模糊、无足够不透明度底板的状态。
   - 结果：抽屉内部的每首歌曲条目（`item.title`, `item.artist`）与底层正在滚动的巨大白色歌词完全重合，造成强烈的视觉干扰和文本不可读。

2. **磨砂毛玻璃材质解决方案推导**：
   - 抽屉浮层属于弹出式模态抽屉（Drawer Overlay），应具备独立的、自包含的高质感毛玻璃材质体系，而不应受底层全局窗口策略的制约。
   - 需要在抽屉容器内部显式使用 `ClipRRect(borderRadius: BorderRadius.circular(24))` 包裹 `BackdropFilter(filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0))`。
   - 配合明暗主题自适应的半透明底色（暗色 82% 不透明度 / 亮色 88% 不透明度）与微光线性渐变（LinearGradient），提供足够的对比度阻隔率，同时隐约透出底层专辑封面的色彩流光。
   - 辅以 1px 微光边框（暗色 `white 12%` / 亮色 `black 8%`）与双层立体阴影（主阴影 + 主题色微光），确立清晰的层级浮空感。

3. **丝滑缓动动效解决方案推导**：
   - 将 `reverseCurve` 由生硬加速的 `Curves.easeInCubic` 调整为具有平滑缓冲的自然曲线 `Cubic(0.2, 0.0, 0.0, 1.0)`（即 `motion.normal` 或 `Curves.easeInOutCubic`）。
   - 将入场曲线采用 `Cubic(0.16, 1.0, 0.3, 1.0)`（即 `motion.fast`，具备轻快起步、柔和制动的 Apple/Fluent 级物理感）。
   - 将动画时长微调至 `Duration(milliseconds: 320)`，使位移与淡入淡出更舒展连贯，彻底消除收起时的瞬变与闪烁。

---

## 3. Caveats (注意事项与边界条件)

1. **性能适配（Performance Fallback）**：
   - 在低性能设备或用户开启极简模式（`effectsLevel == UiEffectsLevel.performance`）时，高斯模糊半径可自适应下调（例如 12.0）或降级为纯半透明底色，确保 60/120fps 满帧运行。
2. **边缘圆角防溢出**：
   - `BackdropFilter` 必须嵌套在具有相同圆角的 `ClipRRect` 内部，否则模糊滤镜会溢出到矩形四角。
3. **平台导入依赖**：
   - 使用 `ImageFilter.blur` 需要确保文件顶部引入 `import 'dart:ui';`。

---

## 4. Conclusion (实施方案与代码建议)

### 4.1 修改涉及文件与位置
- **目标文件**: `e:\PyCharmSave\qisheng_player\lib\component\bottom_player_bar.dart`
- **修改范围**: 顶部引入 `import 'dart:ui';`，重构 `_openQueueDrawer` 及抽屉容器结构。

### 4.2 完整代码方案建议

```dart
// 1. 在 lib/component/bottom_player_bar.dart 顶部添加导入：
import 'dart:ui';

// 2. 替换 _QueueEntryButton 类中的 _openQueueDrawer 方法及配套抽屉组件：
class _QueueEntryButton extends StatelessWidget {
  const _QueueEntryButton({required this.dense});

  final bool dense;

  // 优化：右侧滑出的高质感毛玻璃播放队列抽屉，带自适应半透明底色、高斯模糊与丝滑双向缓动
  Future<void> _openQueueDrawer(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width * 0.36).clamp(380.0, 520.0).toDouble();
    final motion = context.motion;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '播放队列',
      barrierColor: isDark
          ? Colors.black.withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, anim1, anim2) {
        final scheme = Theme.of(context).colorScheme;
        final effectsLevel = context.surfaces.effectsLevel;
        final blurSigma = effectsLevel == UiEffectsLevel.performance ? 12.0 : 24.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width,
              height: double.infinity,
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurSigma,
                    sigmaY: blurSigma,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: isDark
                          ? Color.alphaBlend(
                              scheme.primary.withValues(alpha: 0.08),
                              const Color(0xFF131822).withValues(alpha: 0.82),
                            )
                          : Color.alphaBlend(
                              scheme.primary.withValues(alpha: 0.04),
                              Colors.white.withValues(alpha: 0.86),
                            ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Colors.white.withValues(alpha: 0.06),
                                scheme.primary.withValues(alpha: 0.03),
                                Colors.transparent,
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.65),
                                scheme.surfaceContainerLowest.withValues(alpha: 0.4),
                              ],
                        stops: isDark ? const [0.0, 0.45, 1.0] : null,
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.12),
                          blurRadius: 40,
                          offset: const Offset(-8, 14),
                          spreadRadius: -4,
                        ),
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: isDark ? 0.12 : 0.05),
                          blurRadius: 28,
                          offset: const Offset(-2, 4),
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '播放队列',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              CpIconButton(
                                variant: CpButtonVariant.immersive,
                                tooltip: '关闭',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Symbols.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Expanded(
                            child: CurrentPlaylistView(
                              showHeader: false,
                              dense: true,
                              enableReorder: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Cubic(0.16, 1.0, 0.3, 1.0), // 进场平滑减速
          reverseCurve: const Cubic(0.2, 0.0, 0.0, 1.0), // 退场平滑缓冲，杜绝急停与闪退
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();

    return ValueListenableBuilder<List<Audio>>(
      valueListenable: playback.playlist,
      builder: (context, playlist, _) {
        final canOpenQueue = playlist.isNotEmpty || playback.nowPlaying != null;

        return CpIconButton(
          variant: CpButtonVariant.immersive,
          tooltip: canOpenQueue ? '打开播放队列' : '暂无播放队列',
          onPressed: canOpenQueue ? () => _openQueueDrawer(context) : null,
          icon: Badge(
            label: Text('${playlist.length}'),
            child: const Icon(Symbols.queue_music),
          ),
        );
      },
    );
  }
}
```

---

## 5. Verification Method (独立验证方法)

1. **静态代码分析与类型检查**：
   运行静态分析确保无任何语法错误或警告：
   ```bash
   flutter analyze lib/component/bottom_player_bar.dart
   ```
2. **视觉与交互测试验证点**：
   - 打开全屏正在播放页（`ImmersiveNowPlayingView`），播放带有滚动长歌词与高亮专辑封面的歌曲。
   - 点击右下角播放队列按钮，观察抽屉呼出过程：
     - 进场动画应呈现丝滑的右侧滑入与柔和淡入，无任何卡顿。
     - 展开后，抽屉底板下方的高亮大歌词与封面图应被均匀高斯模糊虚化，抽屉内的歌曲标题与艺术家文字清晰锐利，无重影穿透。
   - 点击抽屉外部遮罩区域或关闭按钮：
     - 观察退场动画，抽屉应以平滑自然的缓冲速度向右滑出并淡出，逆向动效完整执行，无瞬断闪烁。
