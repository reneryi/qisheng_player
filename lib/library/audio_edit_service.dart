import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/now_playing_artwork_hero.dart';
import 'package:qisheng_player/library/artwork_store.dart';
import 'package:qisheng_player/library/audio_library.dart';
import 'package:qisheng_player/library/audio_metadata_override_store.dart';
import 'package:qisheng_player/library/playlist.dart';
import 'package:qisheng_player/lyric/lrc.dart';
import 'package:qisheng_player/lyric/lyric_file_helper.dart';
import 'package:qisheng_player/lyric/lyric_source.dart';
import 'package:qisheng_player/music_matcher.dart';
import 'package:qisheng_player/play_service/play_service.dart';
import 'package:qisheng_player/src/rust/api/metadata_editor.dart' as native;
import 'package:qisheng_player/theme_provider.dart';
import 'package:qisheng_player/utils.dart';

class AudioEditDraft {
  AudioEditDraft(this.audio)
      : title = audio.title,
        artist = audio.artist,
        album = audio.album,
        albumArtist = audio.albumArtist,
        track = audio.track,
        disc = audio.disc {
    if (audio.isCueTrack) writeLyrics = false;
  }
  final Audio audio;
  native.AudioMetadataSnapshot? original;
  String title, artist, album, albumArtist;
  int track, disc;
  SongSearchResult? association, lyricResult, coverResult;
  String? lyrics;
  Uint8List? cover;
  bool writeTitle = false,
      writeArtist = false,
      writeAlbum = false,
      writeAlbumArtist = false,
      writeTrack = false,
      writeDisc = false;
  bool writeLyrics = true, exportLyrics = false, applyLyrics = true;
}

enum AudioEditStatus { failed, saved, indexPending, partial }

class AudioEditResult {
  const AudioEditResult(this.status, this.message);
  final AudioEditStatus status;
  final String message;
  bool get committed => status != AudioEditStatus.failed;
}

class AudioEditService {
  const AudioEditService();
  Future<native.AudioMetadataSnapshot> read(Audio audio) =>
      native.readAudioMetadata(path: audio.mediaPath);

  Future<bool> writeEmbeddedLyrics(Audio audio, String lyrics) async {
    final draft = AudioEditDraft(audio)
      ..original = await read(audio)
      ..writeTitle = false
      ..writeArtist = false
      ..writeAlbum = false
      ..writeAlbumArtist = false
      ..writeTrack = false
      ..writeDisc = false
      ..lyrics = lyrics
      ..writeLyrics = true
      ..exportLyrics = false
      ..applyLyrics = false;
    return (await save(draft)).committed;
  }

  Future<AudioEditResult> save(AudioEditDraft draft) async {
    final audio = draft.audio;
    final warnings = <String>[];
    String? token;
    bool committed = false;
    bool indexPending = false;
    try {
      if (draft.writeTitle && draft.title.trim().isEmpty) {
        throw const FormatException('歌名不能为空');
      }
      if (draft.track < 0 || draft.disc < 0) {
        throw const FormatException('音轨号与碟号不能为负数');
      }
      if ((draft.lyricResult != null || draft.lyrics != null) &&
          !draft.writeLyrics &&
          !draft.exportLyrics &&
          !draft.applyLyrics) {
        throw const FormatException('已选择歌词，请至少选择一种保存方式');
      }
      String? lyric = draft.lyrics;
      if (draft.lyricResult != null && lyric == null) {
        lyric = await LyricFileHelper.fetchOnlineLrcText(draft.lyricResult!);
        if (lyric == null || lyric.trim().isEmpty) {
          throw const FormatException('所选歌词获取失败，请重试或取消该项');
        }
      }
      Uint8List? cover = draft.cover;
      if (draft.coverResult != null) {
        final url = draft.coverResult!.coverUrl;
        if (url == null || url.isEmpty) {
          throw const FormatException('所选歌曲没有可用封面');
        }
        cover = await ArtworkStore.download(url);
      }
      if (cover != null && cover.isNotEmpty) {
        await ArtworkStore.validateImage(cover);
      }
      final support = (await getAppDataDir()).path;
      if (audio.isCueTrack) {
        if (cover != null) {
          throw const FormatException('CUE 分轨不能修改母带封面，请在专辑页设置图片');
        }
        await AudioMetadataOverrideStore.instance.setOverride(
            audio: audio,
            title: draft.writeTitle ? draft.title : audio.title,
            artist: draft.writeArtist ? draft.artist : audio.artist,
            album: draft.writeAlbum ? draft.album : audio.album,
            albumArtist:
                draft.writeAlbumArtist ? draft.albumArtist : audio.albumArtist,
            track: draft.writeTrack ? draft.track : audio.track,
            disc: draft.writeDisc ? draft.disc : audio.disc);
        for (final item in AudioLibrary.instance.audioCollection
            .where((item) => item.path == audio.path)) {
          AudioMetadataOverrideStore.instance.applyToAudio(item);
        }
        committed = true;
        if (lyric != null && draft.writeLyrics) warnings.add('CUE 分轨未写入母带歌词');
      } else {
        final original = draft.original;
        if (original == null) throw const FormatException('尚未读取文件标签，不能保存');
        String? changed(String value, String before) =>
            value == before ? null : value;
        final patch = native.AudioMetadataPatch(
            title: draft.writeTitle
                ? changed(draft.title.trim(), original.title)
                : null,
            artist: draft.writeArtist
                ? changed(draft.artist.trim(), original.artist)
                : null,
            album: draft.writeAlbum
                ? changed(draft.album.trim(), original.album)
                : null,
            albumArtist: draft.writeAlbumArtist
                ? changed(draft.albumArtist.trim(), original.albumArtist)
                : null,
            track: draft.writeTrack && draft.track != original.track
                ? draft.track
                : null,
            disc: draft.writeDisc && draft.disc != original.disc
                ? draft.disc
                : null,
            lyrics: draft.writeLyrics ? lyric : null,
            cover: cover);
        token = await native.prepareAudioMetadata(
            path: audio.mediaPath,
            supportPath: support,
            expectedFingerprint: original.fingerprint,
            patch: patch);
        final playback = PlayService.instance.playbackService;
        final snapshot = await playback.withMetadataFileReleased(
            audio, () => native.commitAudioMetadata(token: token!),
            onRestoreError: (e) => warnings.add('标签已保存，播放恢复失败：$e'));
        committed = true;
        _applySnapshot(audio, snapshot);
        AudioMetadataOverrideStore.instance.forgetCommitted(audio.path);
        try {
          await native.finishAudioMetadata(token: token, supportPath: support);
        } catch (e) {
          indexPending = true;
          warnings.add('文件已保存，索引同步待恢复：$e');
        }
        token = null;
      }
      if (draft.association != null) {
        try {
          await ArtworkStore.instance.associate(audio, draft.association!);
        } catch (e) {
          warnings.add('在线资料关联失败：$e');
        }
      }
      if (lyric != null) {
        if (draft.exportLyrics &&
            !await LyricFileHelper.saveLrcToFile(audio, lyric)) {
          warnings.add('外挂歌词导出失败');
        }
        if (draft.applyLyrics) {
          // Cache selected text locally, including CUE, so restart does not depend on networking.
          try {
            if (!isLyricSourcesLoaded) await readLyricSources();
            if (!isLyricSourcesLoaded) throw StateError("无法载入歌词来源记录");
            LYRIC_SOURCES[audio.path] =
                LyricSource(LyricSourceType.local, cachedText: lyric);
            await saveLyricSources(propagateErrors: true);
          } catch (e) {
            warnings.add('歌词来源保存失败：$e');
          }
        }
      }
      _synchronize(audio);
      if (lyric != null &&
          draft.applyLyrics &&
          PlayService.instance.playbackService.nowPlaying?.path == audio.path) {
        final parsed = Lrc.fromLrcText(lyric, LrcSource.local);
        if (parsed != null) {
          PlayService.instance.lyricService.useSpecificLyric(parsed);
        }
      }
      return AudioEditResult(
          indexPending
              ? AudioEditStatus.indexPending
              : warnings.isEmpty
                  ? AudioEditStatus.saved
                  : AudioEditStatus.partial,
          '${audio.isCueTrack ? "已保存 CUE 播放器覆盖" : "音乐文件已保存并验证"}${warnings.isEmpty ? "，播放器已同步" : "；${warnings.join('；')}"}');
    } catch (e) {
      if (committed) {
        _synchronize(audio);
        return AudioEditResult(AudioEditStatus.partial, '文件已保存，后续同步未完全完成：$e');
      }
      return AudioEditResult(AudioEditStatus.failed, '保存失败，未应用到曲库：$e');
    } finally {
      if (token != null) {
        try {
          await native.cancelAudioMetadata(token: token);
        } catch (e) {
          LOGGER.e('编辑清理失败: $e');
        }
      }
    }
  }

  void _applySnapshot(Audio target, native.AudioMetadataSnapshot s) {
    for (final audio in {
      target,
      ...AudioLibrary.instance.audioCollection
          .where((a) => a.path == target.path)
    }) {
      audio.albumArtist = s.albumArtist;
      audio.track = s.track;
      audio.disc = s.disc;
      audio.modified = s.modified.toInt();
      audio.updateMetadata(title: s.title, artist: s.artist, album: s.album);
      audio.clearCoverCache();
    }
  }

  void _synchronize(Audio audio) {
    audio.clearCoverCache();
    NowPlayingArtworkCard.evictCover(audio.path);
    PaintingBinding.instance.imageCache.clear();
    ThemeProvider.instance.invalidateAudioPalette(audio.path);
    AudioLibrary.instance.rebuildCollectionsFromCurrentFolders();
    for (final playlist in PLAYLISTS) {
      if (playlist.audios.containsKey(audio.path)) {
        playlist.audios[audio.path] = AudioLibrary.instance.audioCollection
                .where((a) => a.path == audio.path)
                .firstOrNull ??
            audio;
      }
    }
    final playback = PlayService.instance.playbackService;
    playback.reconcileLibraryReferences();
    playback.refreshNowPlaying(forceNewInstance: true);
  }
}
