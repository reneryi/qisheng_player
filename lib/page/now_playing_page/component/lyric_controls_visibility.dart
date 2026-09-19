import 'dart:async';

import 'package:flutter/foundation.dart';

class LyricControlsVisibilityController extends ChangeNotifier {
  LyricControlsVisibilityController({
    this.hideDelay = const Duration(milliseconds: 160),
    this.idleHideDelay = const Duration(milliseconds: 2600),
  });

  final Duration hideDelay;
  final Duration idleHideDelay;

  bool _regionHovered = false;
  bool _controlsHovered = false;
  bool _menuOpen = false;
  bool _visible = false;
  Timer? _hideTimer;
  Timer? _idleTimer;

  bool get visible => _visible;

  void setRegionHovered(bool hovered) {
    _regionHovered = hovered;
    if (hovered) {
      _showAndScheduleIdle();
    } else {
      _idleTimer?.cancel();
      _syncVisibility();
    }
  }

  /// 鼠标在歌词区域内活跃移动，唤醒控制按钮并重置闲置隐身倒计时
  void onRegionPointerMove() {
    _regionHovered = true;
    _showAndScheduleIdle();
  }

  void setControlsHovered(bool hovered) {
    _controlsHovered = hovered;
    if (hovered) {
      // 鼠标直接悬停在控制按钮上时，持续常亮，杜绝在用户浏览/点击时意外隐身
      _idleTimer?.cancel();
      _hideTimer?.cancel();
      _setVisible(true);
    } else {
      _syncVisibility();
    }
  }

  void setMenuOpen(bool open) {
    _menuOpen = open;
    if (open) {
      _idleTimer?.cancel();
      _hideTimer?.cancel();
      _setVisible(true);
    } else {
      _syncVisibility();
    }
  }

  void _showAndScheduleIdle() {
    _hideTimer?.cancel();
    _setVisible(true);

    if (_controlsHovered || _menuOpen) {
      _idleTimer?.cancel();
      return;
    }

    _idleTimer?.cancel();
    _idleTimer = Timer(idleHideDelay, () {
      if (!_controlsHovered && !_menuOpen) {
        _setVisible(false);
      }
    });
  }

  void _syncVisibility() {
    final shouldKeepVisible = _controlsHovered || _menuOpen;
    if (shouldKeepVisible) {
      _hideTimer?.cancel();
      _idleTimer?.cancel();
      _setVisible(true);
      return;
    }

    if (_regionHovered) {
      // 仍处于歌词主区域，但不处于按钮上：开启闲置隐身倒计时
      _showAndScheduleIdle();
      return;
    }

    // 指针完全离开歌词区域，快速执行隐身退场动画
    _idleTimer?.cancel();
    _hideTimer?.cancel();
    final effectiveDelay = hideDelay == Duration.zero
        ? Duration.zero
        : hideDelay + const Duration(milliseconds: 1);
    _hideTimer = Timer(effectiveDelay, () {
      if (!_regionHovered && !_controlsHovered && !_menuOpen) {
        _setVisible(false);
      }
    });
  }

  void _setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }
}
