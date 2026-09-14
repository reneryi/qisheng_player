// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InitArgsMessage _$InitArgsMessageFromJson(Map<String, dynamic> json) =>
    InitArgsMessage(
      json['isPlaying'] as bool,
      json['title'] as String,
      json['artist'] as String,
      json['album'] as String,
      json['darkMode'] as bool,
      (json['primary'] as num).toInt(),
      (json['surfaceContainer'] as num).toInt(),
      (json['onSurface'] as num).toInt(),
      lyricFontFamily: json['lyricFontFamily'] as String?,
      followPlayerFont: json['followPlayerFont'] as bool? ?? true,
      hasSpecifiedColor: json['hasSpecifiedColor'] as bool? ?? false,
      playerFontFamily: json['playerFontFamily'] as String?,
    );

Map<String, dynamic> _$InitArgsMessageToJson(InitArgsMessage instance) =>
    <String, dynamic>{
      'isPlaying': instance.isPlaying,
      'title': instance.title,
      'artist': instance.artist,
      'album': instance.album,
      'darkMode': instance.darkMode,
      'primary': instance.primary,
      'surfaceContainer': instance.surfaceContainer,
      'onSurface': instance.onSurface,
      'lyricFontFamily': instance.lyricFontFamily,
      'followPlayerFont': instance.followPlayerFont,
      'hasSpecifiedColor': instance.hasSpecifiedColor,
      'playerFontFamily': instance.playerFontFamily,
    };

ControlEventMessage _$ControlEventMessageFromJson(Map<String, dynamic> json) =>
    ControlEventMessage(
      $enumDecode(_$ControlEventEnumMap, json['event']),
    );

Map<String, dynamic> _$ControlEventMessageToJson(
        ControlEventMessage instance) =>
    <String, dynamic>{
      'event': _$ControlEventEnumMap[instance.event]!,
    };

const _$ControlEventEnumMap = {
  ControlEvent.pause: 0,
  ControlEvent.start: 1,
  ControlEvent.previousAudio: 2,
  ControlEvent.nextAudio: 3,
  ControlEvent.lock: 4,
  ControlEvent.close: 5,
};

PreferenceChangedMessage _$PreferenceChangedMessageFromJson(
        Map<String, dynamic> json) =>
    PreferenceChangedMessage(
      (json['primary'] as num?)?.toInt(),
      (json['surfaceContainer'] as num).toInt(),
      (json['onSurface'] as num).toInt(),
      hasSpecifiedColor: json['hasSpecifiedColor'] as bool?,
      lyricFontFamily: json['lyricFontFamily'] as String?,
      followPlayerFont: json['followPlayerFont'] as bool?,
    );

Map<String, dynamic> _$PreferenceChangedMessageToJson(
        PreferenceChangedMessage instance) =>
    <String, dynamic>{
      'primary': instance.primary,
      'surfaceContainer': instance.surfaceContainer,
      'onSurface': instance.onSurface,
      'hasSpecifiedColor': instance.hasSpecifiedColor,
      'lyricFontFamily': instance.lyricFontFamily,
      'followPlayerFont': instance.followPlayerFont,
    };

PlayerStateChangedMessage _$PlayerStateChangedMessageFromJson(
        Map<String, dynamic> json) =>
    PlayerStateChangedMessage(
      json['playing'] as bool,
    );

Map<String, dynamic> _$PlayerStateChangedMessageToJson(
        PlayerStateChangedMessage instance) =>
    <String, dynamic>{
      'playing': instance.playing,
    };

NowPlayingChangedMessage _$NowPlayingChangedMessageFromJson(
        Map<String, dynamic> json) =>
    NowPlayingChangedMessage(
      json['title'] as String,
      json['artist'] as String,
      json['album'] as String,
    );

Map<String, dynamic> _$NowPlayingChangedMessageToJson(
        NowPlayingChangedMessage instance) =>
    <String, dynamic>{
      'title': instance.title,
      'artist': instance.artist,
      'album': instance.album,
    };

LyricLineChangedMessage _$LyricLineChangedMessageFromJson(
        Map<String, dynamic> json) =>
    LyricLineChangedMessage(
      json['content'] as String,
      Duration(microseconds: (json['length'] as num).toInt()),
      json['translation'] as String?,
    );

Map<String, dynamic> _$LyricLineChangedMessageToJson(
        LyricLineChangedMessage instance) =>
    <String, dynamic>{
      'content': instance.content,
      'translation': instance.translation,
      'length': instance.length.inMicroseconds,
    };

ThemeModeChangedMessage _$ThemeModeChangedMessageFromJson(
        Map<String, dynamic> json) =>
    ThemeModeChangedMessage(
      json['darkMode'] as bool,
    );

Map<String, dynamic> _$ThemeModeChangedMessageToJson(
        ThemeModeChangedMessage instance) =>
    <String, dynamic>{
      'darkMode': instance.darkMode,
    };

ThemeChangedMessage _$ThemeChangedMessageFromJson(Map<String, dynamic> json) =>
    ThemeChangedMessage(
      (json['primary'] as num).toInt(),
      (json['surfaceContainer'] as num).toInt(),
      (json['onSurface'] as num).toInt(),
    );

Map<String, dynamic> _$ThemeChangedMessageToJson(
        ThemeChangedMessage instance) =>
    <String, dynamic>{
      'primary': instance.primary,
      'surfaceContainer': instance.surfaceContainer,
      'onSurface': instance.onSurface,
    };

UnlockMessage _$UnlockMessageFromJson(Map<String, dynamic> json) =>
    const UnlockMessage();

Map<String, dynamic> _$UnlockMessageToJson(UnlockMessage instance) =>
    <String, dynamic>{};

PlayerFontChangedMessage _$PlayerFontChangedMessageFromJson(
        Map<String, dynamic> json) =>
    PlayerFontChangedMessage(
      json['fontFamily'] as String?,
    );

Map<String, dynamic> _$PlayerFontChangedMessageToJson(
        PlayerFontChangedMessage instance) =>
    <String, dynamic>{
      'fontFamily': instance.fontFamily,
    };
