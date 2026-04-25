import 'package:coriander_player/library/audio_library.dart';

const albumArtworkHeroTagPrefix = 'album-artwork';

String? albumArtworkHeroTag(Album album) {
  if (album.works.isEmpty) return null;

  final firstPath = album.works.first.path;
  if (firstPath.isEmpty) return null;

  return '$albumArtworkHeroTagPrefix:${album.name}:$firstPath';
}
