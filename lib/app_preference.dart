import 'dart:convert';
import 'dart:io';

import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:qisheng_player/page/now_playing_page/page.dart';
import 'package:qisheng_player/page/uni_page.dart';
import 'package:qisheng_player/play_service/playback_service.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/services.dart';

class PagePreference {
  int sortMethod;
  SortOrder sortOrder;
  ContentView contentView;
  bool showLyricPreview;

  PagePreference(
    this.sortMethod,
    this.sortOrder,
    this.contentView, {
    this.showLyricPreview = false,
  });

  Map toMap() => {
        "sortMethod": sortMethod,
        "sortOrder": sortOrder.name,
        "contentView": contentView.name,
        "showLyricPreview": showLyricPreview,
      };

  factory PagePreference.fromMap(Map map) => PagePreference(
        map["sortMethod"] ?? 0,
        SortOrder.fromString(map["sortOrder"]) ?? SortOrder.ascending,
        ContentView.fromString(map["contentView"]) ?? ContentView.list,
        showLyricPreview: map["showLyricPreview"] ?? false,
      );
}

enum NowPlayingStyleMode {
  immersive,
  studio;

  static NowPlayingStyleMode? fromString(String? value) {
    for (final mode in NowPlayingStyleMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}

class NowPlayingPagePreference {
  NowPlayingViewMode nowPlayingViewMode;
  NowPlayingStyleMode styleMode;
  LyricTextAlign lyricTextAlign;
  bool showTranslation;
  double lyricFontSize;
  double translationFontSize;

  NowPlayingPagePreference(
    this.nowPlayingViewMode,
    this.styleMode,
    this.lyricTextAlign,
    this.showTranslation,
    this.lyricFontSize,
    this.translationFontSize,
  );

  Map toMap() => {
        "nowPlayingViewMode": nowPlayingViewMode.name,
        "styleMode": styleMode.name,
        "lyricTextAlign": lyricTextAlign.name,
        "showTranslation": showTranslation,
        "lyricFontSize": lyricFontSize,
        "translationFontSize": translationFontSize,
      };

  factory NowPlayingPagePreference.fromMap(Map map) {
    return NowPlayingPagePreference(
      NowPlayingViewMode.fromString(map["nowPlayingViewMode"]) ??
          NowPlayingViewMode.withLyric,
      NowPlayingStyleMode.fromString(map["styleMode"]) ??
          NowPlayingStyleMode.immersive,
      LyricTextAlign.fromString(map["lyricTextAlign"]) ?? LyricTextAlign.left,
      map["showTranslation"] ?? true,
      map["lyricFontSize"] ?? 22.0,
      map["translationFontSize"] ?? 18.0,
    );
  }
}

class PlaybackPreference {
  PlayMode playMode;
  double volumeDsp;
  bool enableVolumeLeveling;
  double volumeLevelingPreampDb;
  String? lastAudioPath;
  List<String> lastPlaylistPaths;
  int lastPlaylistIndex;
  double lastPosition;

  PlaybackPreference(
    this.playMode,
    this.volumeDsp,
    this.enableVolumeLeveling,
    this.volumeLevelingPreampDb,
    this.lastAudioPath,
    this.lastPlaylistPaths,
    this.lastPlaylistIndex,
    this.lastPosition,
  );

  Map toMap() => {
        "playMode": playMode.name,
        "volumeDsp": volumeDsp,
        "enableVolumeLeveling": enableVolumeLeveling,
        "volumeLevelingPreampDb": volumeLevelingPreampDb,
        "lastAudioPath": lastAudioPath,
        "lastPlaylistPaths": lastPlaylistPaths,
        "lastPlaylistIndex": lastPlaylistIndex,
        "lastPosition": lastPosition,
      };

  factory PlaybackPreference.fromMap(Map map) => PlaybackPreference(
        PlayMode.fromString(map["playMode"]) ?? PlayMode.forward,
        map["volumeDsp"] ?? 1.0,
        map["enableVolumeLeveling"] ?? false,
        (map["volumeLevelingPreampDb"] as num?)?.toDouble() ?? 0.0,
        map["lastAudioPath"]?.toString(),
        (map["lastPlaylistPaths"] as List?)
                ?.map((item) => item.toString())
                .toList() ??
            const [],
        (map["lastPlaylistIndex"] as num?)?.toInt() ?? 0,
        (map["lastPosition"] as num?)?.toDouble() ?? 0.0,
      );
}

class DesktopLyricPreference {
  /// 閫€鍑哄墠妗岄潰姝岃瘝鏄惁澶勪簬寮€鍚姸鎬?
  bool enabled;

  /// 閫€鍑哄墠妗岄潰姝岃瘝鏄惁閿佸畾
  bool locked;

  /// 妗岄潰姝岃瘝鍋忓ソ涓婚鑹?
  int? primary;
  int? surfaceContainer;
  int? onSurface;
  double? windowLeft;
  double? windowTop;

  DesktopLyricPreference(
    this.enabled,
    this.locked,
    this.primary,
    this.surfaceContainer,
    this.onSurface,
    this.windowLeft,
    this.windowTop,
  );

  Map toMap() => {
        "enabled": enabled,
        "locked": locked,
        "primary": primary,
        "surfaceContainer": surfaceContainer,
        "onSurface": onSurface,
        "windowLeft": windowLeft,
        "windowTop": windowTop,
      };

  factory DesktopLyricPreference.fromMap(Map map) => DesktopLyricPreference(
        map["enabled"] ?? false,
        map["locked"] ?? false,
        map["primary"],
        map["surfaceContainer"],
        map["onSurface"],
        (map["windowLeft"] as num?)?.toDouble(),
        (map["windowTop"] as num?)?.toDouble(),
      );
}

class HotkeyBindingPreference {
  int keyId;
  List<String> modifiers;

  HotkeyBindingPreference(this.keyId, this.modifiers);

  Map<String, dynamic> toMap() => {
        "keyId": keyId,
        "modifiers": modifiers,
      };

  factory HotkeyBindingPreference.fromMap(Map map) => HotkeyBindingPreference(
        (map["keyId"] as num?)?.toInt() ??
            PhysicalKeyboardKey.space.usbHidUsage,
        (map["modifiers"] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class HotkeyPreference {
  Map<String, HotkeyBindingPreference> bindings;

  HotkeyPreference(this.bindings);

  static HotkeyPreference defaults() => HotkeyPreference({
        "playPause": HotkeyBindingPreference(
          PhysicalKeyboardKey.space.usbHidUsage,
          const [],
        ),
        "previous": HotkeyBindingPreference(
          PhysicalKeyboardKey.arrowLeft.usbHidUsage,
          const [],
        ),
        "next": HotkeyBindingPreference(
          PhysicalKeyboardKey.arrowRight.usbHidUsage,
          const [],
        ),
        "volumeUp": HotkeyBindingPreference(
          PhysicalKeyboardKey.arrowUp.usbHidUsage,
          const [],
        ),
        "volumeDown": HotkeyBindingPreference(
          PhysicalKeyboardKey.arrowDown.usbHidUsage,
          const [],
        ),
        "mute": HotkeyBindingPreference(
          PhysicalKeyboardKey.keyM.usbHidUsage,
          const ["alt"],
        ),
        "toggleDesktopLyric": HotkeyBindingPreference(
          PhysicalKeyboardKey.keyM.usbHidUsage,
          const ["control"],
        ),
        "toggleMainWindow": HotkeyBindingPreference(
          PhysicalKeyboardKey.keyH.usbHidUsage,
          const ["control"],
        ),
        "goBack": HotkeyBindingPreference(
          PhysicalKeyboardKey.escape.usbHidUsage,
          const [],
        ),
        "goForward": HotkeyBindingPreference(
          PhysicalKeyboardKey.browserForward.usbHidUsage,
          const [],
        ),
        "quit": HotkeyBindingPreference(
          PhysicalKeyboardKey.keyQ.usbHidUsage,
          const ["control"],
        ),
      });

  Map<String, dynamic> toMap() => {
        for (final entry in bindings.entries) entry.key: entry.value.toMap(),
      };

  factory HotkeyPreference.fromMap(Map map) {
    final base = HotkeyPreference.defaults();
    for (final entry in map.entries) {
      if (entry.value is Map && base.bindings.containsKey(entry.key)) {
        base.bindings[entry.key] =
            HotkeyBindingPreference.fromMap(entry.value as Map);
      }
    }
    return base;
  }
}

class AppPreference {
  var audiosPagePref = PagePreference(0, SortOrder.ascending, ContentView.list);

  var artistsPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.table);

  var artistDetailPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.list);

  var albumsPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.table);

  var albumDetailPagePref =
      PagePreference(2, SortOrder.ascending, ContentView.list);

  var foldersPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.list);

  var folderDetailPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.list);

  var playlistsPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.list);

  var playlistDetailPagePref =
      PagePreference(0, SortOrder.ascending, ContentView.list);

  bool sidebarCollapsedLarge = false;

  int startPage = 0;

  String? ignoredUpdateTag;

  var playbackPref = PlaybackPreference(
    PlayMode.forward,
    0.2,
    false,
    0.0,
    null,
    const [],
    0,
    0.0,
  );

  var desktopLyricPref =
      DesktopLyricPreference(false, false, null, null, null, null, null);

  var nowPlayingPagePref = NowPlayingPagePreference(
    NowPlayingViewMode.withLyric,
    NowPlayingStyleMode.immersive,
    LyricTextAlign.left,
    true,
    22.0,
    18.0,
  );

  var hotkeyPref = HotkeyPreference.defaults();

  Future<void> save() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final appPreferencePath = "$supportPath\\app_preference.json";

      Map prefMap = {
        "audiosPagePref": audiosPagePref.toMap(),
        "artistsPagePref": artistsPagePref.toMap(),
        "artistDetailPagePref": artistDetailPagePref.toMap(),
        "albumsPagePref": albumsPagePref.toMap(),
        "albumDetailPagePref": albumDetailPagePref.toMap(),
        "foldersPagePref": foldersPagePref.toMap(),
        "folderDetailPagePref": folderDetailPagePref.toMap(),
        "playlistsPagePref": playlistsPagePref.toMap(),
        "playlistDetailPagePref": playlistDetailPagePref.toMap(),
        "audiosDefaultSortMigrated": true,
        "sidebarCollapsedLarge": sidebarCollapsedLarge,
        "startPage": startPage,
        "ignoredUpdateTag": ignoredUpdateTag,
        "playbackPref": playbackPref.toMap(),
        "desktopLyricPref": desktopLyricPref.toMap(),
        "nowPlayingPagePref": nowPlayingPagePref.toMap(),
        "hotkeyPref": hotkeyPref.toMap(),
      };

      final prefJson = json.encode(prefMap);
      final output = await File(appPreferencePath).create(recursive: true);
      await output.writeAsString(prefJson);
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  static Future<void> read() async {
    try {
      final supportPath = (await getAppDataDir()).path;
      final appPreferencePath = "$supportPath\\app_preference.json";

      final prefJson = await File(appPreferencePath).readAsString();
      if (prefJson.trim().isEmpty) return;
      final Map prefMap = json.decode(prefJson);

      instance.audiosPagePref =
          PagePreference.fromMap(prefMap["audiosPagePref"]);
      final needNormalizeAudiosSort =
          prefMap["audiosDefaultSortMigrated"] != true;
      if (needNormalizeAudiosSort) {
        instance.audiosPagePref
          ..sortMethod = 0
          ..sortOrder = SortOrder.ascending;
      }
      instance.artistsPagePref =
          PagePreference.fromMap(prefMap["artistsPagePref"]);
      instance.artistDetailPagePref = PagePreference.fromMap(
        prefMap["artistDetailPagePref"],
      );
      instance.albumsPagePref =
          PagePreference.fromMap(prefMap["albumsPagePref"]);
      instance.albumDetailPagePref = PagePreference.fromMap(
        prefMap["albumDetailPagePref"],
      );
      instance.foldersPagePref =
          PagePreference.fromMap(prefMap["foldersPagePref"]);
      instance.folderDetailPagePref = PagePreference.fromMap(
        prefMap["folderDetailPagePref"],
      );
      instance.playlistsPagePref = PagePreference.fromMap(
        prefMap["playlistsPagePref"],
      );
      instance.playlistDetailPagePref = PagePreference.fromMap(
        prefMap["playlistDetailPagePref"],
      );
      instance.sidebarCollapsedLarge =
          prefMap["sidebarCollapsedLarge"] ?? false;
      instance.ignoredUpdateTag = prefMap["ignoredUpdateTag"]?.toString();
      final needNormalizeStartPage = prefMap["startPage"] != 0;
      // 鏃х増浼氭妸鏈€鍚庣偣鍑荤殑渚ф爮椤甸潰鍐欐垚鍚姩椤碉紱娌℃湁鏄惧紡璁剧疆鏃剁粺涓€鍥炲埌闊充箰椤点€?
      instance.startPage = 0;
      final loadedPlaybackPref =
          PlaybackPreference.fromMap(prefMap["playbackPref"]);
      // Normalize historical startup-at-100% volume bug once.
      final needNormalizeVolume = loadedPlaybackPref.volumeDsp >= 0.999;
      final normalizedVolume = needNormalizeVolume
          ? 0.2
          : loadedPlaybackPref.volumeDsp.clamp(0.0, 1.0);
      instance.playbackPref
        ..playMode = loadedPlaybackPref.playMode
        ..volumeDsp = normalizedVolume
        ..enableVolumeLeveling = loadedPlaybackPref.enableVolumeLeveling
        ..volumeLevelingPreampDb = loadedPlaybackPref.volumeLevelingPreampDb
        ..lastAudioPath = loadedPlaybackPref.lastAudioPath
        ..lastPlaylistPaths = loadedPlaybackPref.lastPlaylistPaths
        ..lastPlaylistIndex = loadedPlaybackPref.lastPlaylistIndex
        ..lastPosition = loadedPlaybackPref.lastPosition;

      final loadedDesktopLyricPref = DesktopLyricPreference.fromMap(
        prefMap["desktopLyricPref"] ?? {},
      );
      instance.desktopLyricPref
        ..enabled = loadedDesktopLyricPref.enabled
        ..locked = loadedDesktopLyricPref.locked
        ..primary = loadedDesktopLyricPref.primary
        ..surfaceContainer = loadedDesktopLyricPref.surfaceContainer
        ..onSurface = loadedDesktopLyricPref.onSurface
        ..windowLeft = loadedDesktopLyricPref.windowLeft
        ..windowTop = loadedDesktopLyricPref.windowTop;

      final loadedNowPlayingPref =
          NowPlayingPagePreference.fromMap(prefMap["nowPlayingPagePref"]);
      instance.nowPlayingPagePref
        ..nowPlayingViewMode = loadedNowPlayingPref.nowPlayingViewMode
        ..styleMode = loadedNowPlayingPref.styleMode
        ..lyricTextAlign = loadedNowPlayingPref.lyricTextAlign
        ..showTranslation = loadedNowPlayingPref.showTranslation
        ..lyricFontSize = loadedNowPlayingPref.lyricFontSize
        ..translationFontSize = loadedNowPlayingPref.translationFontSize;

      instance.hotkeyPref = HotkeyPreference.fromMap(
        prefMap["hotkeyPref"] ?? {},
      );
      bool needNormalizeMuteHotkey = false;
      final muteBinding = instance.hotkeyPref.bindings["mute"];
      if (muteBinding != null &&
          muteBinding.keyId == PhysicalKeyboardKey.keyM.usbHidUsage &&
          muteBinding.modifiers.isEmpty) {
        muteBinding.modifiers = ["alt"];
        needNormalizeMuteHotkey = true;
      }

      if (needNormalizeStartPage ||
          needNormalizeAudiosSort ||
          needNormalizeVolume ||
          needNormalizeMuteHotkey) {
        await instance.save();
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
    }
  }

  static final AppPreference instance = AppPreference();
}
