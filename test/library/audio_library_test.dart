import 'dart:convert';

import 'package:qisheng_player/library/audio_library.dart';
import 'package:flutter_test/flutter_test.dart';

String _latin1Mojibake(String value) {
  return String.fromCharCodes(utf8.encode(value));
}

void main() {
  test('Audio.fromMap keeps composer and arranger nullable for old index data',
      () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': 'Artist',
      'album': 'Album',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.composer, isNull);
    expect(audio.arranger, isNull);
  });

  test('Audio.fromMap reads composer and arranger from new index data', () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': 'Artist',
      'album': 'Album',
      'composer': 'Joe Hisaishi',
      'arranger': 'Yvan Cassar',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.composer, 'Joe Hisaishi');
    expect(audio.arranger, 'Yvan Cassar');
  });

  test('Audio.fromMap localizes unknown artist and album names', () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': 'UNKNOWN',
      'album': 'UNKNOWN',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.artist, '未知艺术家');
    expect(audio.album, '未知专辑');
    expect(audio.splitedArtists, ['未知艺术家']);
  });

  test('Audio.fromMap normalizes split artists for display', () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': ' Artist A / Artist A / UNKNOWN / 未知艺术家 / Artist B ',
      'album': 'Album',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.splitedArtists, ['Artist A', 'Artist B']);
    expect(audio.displayArtist, 'Artist A / Artist B');
  });

  test('Audio displayArtistAlbumLine hides unknown album text', () {
    final audio = Audio.fromMap({
      'title': 'Song',
      'artist': 'Artist',
      'album': 'UNKNOWN',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.displayAlbum, '未知专辑');
    expect(audio.displayArtistAlbumLine, 'Artist');
  });

  test('Audio.fromMap repairs common UTF-8 mojibake in metadata', () {
    final garbledChinese = String.fromCharCodes([
      0xE4,
      0xB8,
      0xAD,
      0xE6,
      0x2013,
      0x2021,
    ]);
    final audio = Audio.fromMap({
      'title': garbledChinese,
      'artist': garbledChinese,
      'album': garbledChinese,
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.title, '中文');
    expect(audio.artist, '中文');
    expect(audio.album, '中文');
  });

  test('Audio.fromMap repairs mojibake containing C1 control characters', () {
    final garbledJapanese = _latin1Mojibake('銇撱倱銇仭銇?');
    final audio = Audio.fromMap({
      'title': garbledJapanese,
      'artist': garbledJapanese,
      'album': garbledJapanese,
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.title, '銇撱倱銇仭銇?');
    expect(audio.artist, '銇撱倱銇仭銇?');
    expect(audio.album, '銇撱倱銇仭銇?');
  });

  test('Audio.fromMap repairs Korean and Traditional Chinese mojibake', () {
    final garbledKorean = _latin1Mojibake('鞚岇晠');
    final garbledTraditionalChinese = _latin1Mojibake('繁體中文');
    final audio = Audio.fromMap({
      'title': garbledKorean,
      'artist': garbledTraditionalChinese,
      'album': garbledTraditionalChinese,
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.title, '鞚岇晠');
    expect(audio.artist, '繁體中文');
    expect(audio.album, '繁體中文');
  });

  test('Audio.fromMap preserves emoji while repairing mojibake', () {
    final garbled = _latin1Mojibake('歌🎀');
    final audio = Audio.fromMap({
      'title': garbled,
      'artist': 'Artist',
      'album': 'Album',
      'path': r'E:\Music\Song.flac',
      'modified': 1,
      'created': 1,
    });

    expect(audio.title, '歌🎀');
  });
}
