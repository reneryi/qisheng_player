// ignore_for_file: unnecessary_this

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:pinyin/pinyin.dart';

extension StringHMMSS on Duration {
  /// Returns a string with hours, minutes, seconds,
  /// in the following format: H:MM:SS
  String toStringHMMSS() {
    return toString().split(".").first;
  }
}

/// 把 [dec] 表示成两位 hex
String _toHexString(int dec) {
  assert(dec >= 0 && dec <= 0xff);

  var hex = dec.toRadixString(16);
  if (hex.length == 1) hex = "0$hex";
  return hex;
}

int _toColorByte(double channel) =>
    (channel * 255.0).round().clamp(0, 255).toInt();

extension RGBHexString on Color {
  String toRGBHexString() {
    final redHex = _toHexString(_toColorByte(r));
    final greenHex = _toHexString(_toColorByte(g));
    final blueHex = _toHexString(_toColorByte(b));

    return "#$redHex$greenHex$blueHex";
  }
}

/// [rgbHexStr] 必须是 #RRGGBB
Color? fromRGBHexString(String rgbHexStr) {
  if (rgbHexStr.startsWith("#") && rgbHexStr.length == 7) {
    return Color(0xff000000 + int.parse(rgbHexStr.substring(1), radix: 16));
  }

  return null;
}

Map<String, String> _pinyinCache = {};
Map<String, String> _localeSortKeyCache = {};

extension PinyinCompare on String {
  static final Set<String> _ignorableSymbols = {
    ' ',
    '\t',
    '\r',
    '\n',
    '-',
    '_',
    '.',
    ',',
    '/',
    '\\',
    '|',
    '(',
    ')',
    '[',
    ']',
    '{',
    '}',
    '+',
    '=',
    '*',
    '&',
    '^',
    '%',
    r'$',
    '#',
    '@',
    '!',
    '?',
    '~',
    '`',
    ':',
    ';',
    '"',
    "'",
    '<',
    '>',
    '，',
    '。',
    '、',
    '；',
    '：',
    '（',
    '）',
    '【',
    '】',
    '《',
    '》',
    '「',
    '」',
    '“',
    '”',
    '‘',
    '’',
    '·',
  };

  static bool _isAsciiLetterOrDigit(int codeUnit) {
    return (codeUnit >= 48 && codeUnit <= 57) ||
        (codeUnit >= 65 && codeUnit <= 90) ||
        (codeUnit >= 97 && codeUnit <= 122);
  }

  /// convert str to pinyin, cache it when it hasn't been converted;
  String _getPinyin() {
    final cachedPinyin = _pinyinCache[this];
    if (cachedPinyin != null) return cachedPinyin;

    final splited = this.split("");
    final pinyinBuilder = StringBuffer();

    for (var c in splited) {
      if (ChineseHelper.isChinese(c)) {
        final pinyin = PinyinHelper.convertToPinyinArray(
          c,
          PinyinFormat.WITHOUT_TONE,
        ).firstOrNull;

        pinyinBuilder.write(pinyin ?? c);
      } else {
        pinyinBuilder.write(c);
      }
    }

    final pinyin = pinyinBuilder.toString();

    _pinyinCache[this] = pinyin;

    return pinyin;
  }

  /// 统一中英文和常见符号的比较键，避免中英文被分段排序。
  String toLocaleSortKey() {
    final cached = _localeSortKeyCache[this];
    if (cached != null) return cached;

    final trimmed = trim();
    if (trimmed.isEmpty) {
      _localeSortKeyCache[this] = "";
      return "";
    }

    final buffer = StringBuffer();
    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (ChineseHelper.isChinese(char)) {
        final pinyin = PinyinHelper.convertToPinyinArray(
          char,
          PinyinFormat.WITHOUT_TONE,
        ).firstOrNull;
        buffer.write((pinyin ?? char).toLowerCase());
        continue;
      }

      if (_ignorableSymbols.contains(char)) continue;

      if (char.length == 1 && _isAsciiLetterOrDigit(char.codeUnitAt(0))) {
        buffer.write(char.toLowerCase());
        continue;
      }

      buffer.write(char.toLowerCase());
    }

    final key = buffer.toString();
    final resolved = key.isEmpty ? trimmed.toLowerCase() : key;
    _localeSortKeyCache[this] = resolved;
    return resolved;
  }

  /// Compares this string to [other] with pinyin first, else use the ordering of the code units.
  ///
  /// Returns a negative value if `this` is ordered before `other`,
  /// a positive value if `this` is ordered after `other`,
  /// or zero if `this` and `other` are equivalent.
  int localeCompareTo(String other) {
    final thisSortKey = toLocaleSortKey();
    final otherSortKey = other.toLocaleSortKey();
    final sortKeyResult = thisSortKey.compareTo(otherSortKey);
    if (sortKeyResult != 0) return sortKeyResult;

    final thisContainsChinese = ChineseHelper.containsChinese(this);
    final otherContainsChinese = ChineseHelper.containsChinese(other);

    final thisCmpStr = thisContainsChinese ? this._getPinyin() : this;
    final otherCmpStr = otherContainsChinese ? other._getPinyin() : other;
    final thisNormalized = thisCmpStr.toLowerCase();
    final otherNormalized = otherCmpStr.toLowerCase();
    final normalizedResult = thisNormalized.compareTo(otherNormalized);
    if (normalizedResult != 0) return normalizedResult;
    return thisCmpStr.compareTo(otherCmpStr);
  }
}

final GlobalKey<NavigatorState> ROUTER_KEY = GlobalKey();

final SCAFFOLD_MESSAGER = GlobalKey<ScaffoldMessengerState>();
void showTextOnSnackBar(String text) {
  SCAFFOLD_MESSAGER.currentState?.showSnackBar(SnackBar(content: Text(text)));
}

String formatMusicCount(int count) => '$count 首音乐';

String formatSongCount(int count) => '$count 首歌曲';

String formatWorkCount(int count) => '$count 首作品';

String formatAlbumCount(int count) => '$count 张专辑';

String formatArtistCount(int count) => '$count 位艺术家';

String formatFolderCount(int count) => '$count 个文件夹';

String formatPlaylistCount(int count) => '$count 个歌单';

final LOGGER_MEMORY = MemoryOutput(
  secondOutput: kDebugMode ? ConsoleOutput() : null,
);
final LOGGER = Logger(
  filter: ProductionFilter(),
  printer: SimplePrinter(colors: false),
  output: LOGGER_MEMORY,
  level: Level.all,
);
