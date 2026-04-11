// lib/data/models/track.dart
import 'package:hive/hive.dart';
part 'track.g.dart';

enum TrackSource { local }
enum PlaybackTier { standard, hiRes, bitPerfect }

@HiveType(typeId: 0)
class Track extends HiveObject {
  @HiveField(0)  final String  id;
  @HiveField(1)  final String  title;
  @HiveField(2)  final String  artist;
  @HiveField(3)  final String  album;
  @HiveField(4)  final String? albumArtUri;
  @HiveField(5)  final String? localPath;
  @HiveField(6)  final String? streamUrl;
  @HiveField(7)  final String? originalUrl;
  @HiveField(8)  final int     durationMs;
  @HiveField(9)  final int?    bitrate;
  @HiveField(10) final int?    sampleRate;
  @HiveField(11) final int?    bitDepth;
  @HiveField(12) final String? codec;
  @HiveField(13) final String  sourceType;
  @HiveField(14) final String? lyricsLrc;
  @HiveField(15) final bool    isFavorite;
  @HiveField(16) final DateTime? addedAt;
  @HiveField(17) final int     playCount;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album      = '',
    this.albumArtUri,
    this.localPath,
    this.streamUrl,
    this.originalUrl,
    required this.durationMs,
    this.bitrate,
    this.sampleRate,
    this.bitDepth,
    this.codec,
    this.sourceType  = 'local',
    this.lyricsLrc,
    this.isFavorite  = false,
    this.addedAt,
    this.playCount   = 0,
  });

  TrackSource get source => TrackSource.local;
  bool get isLocal   => true;
  bool get isHiRes   => (sampleRate ?? 0) > 48000 || (bitDepth ?? 16) > 16;
  Duration get duration => Duration(milliseconds: durationMs);

  String get qualityBadge {
    if (codec?.toUpperCase() == 'FLAC') return 'FLAC';
    if (isHiRes) return 'Hi-Res';
    return '';
  }

  Track copyWith({String? streamUrl, String? lyricsLrc,
      bool? isFavorite, int? playCount}) {
    return Track(
      id: id, title: title, artist: artist, album: album,
      albumArtUri: albumArtUri, localPath: localPath,
      streamUrl:  streamUrl   ?? this.streamUrl,
      originalUrl: originalUrl,
      durationMs: durationMs, bitrate: bitrate,
      sampleRate: sampleRate, bitDepth: bitDepth, codec: codec,
      sourceType: sourceType,
      lyricsLrc:  lyricsLrc   ?? this.lyricsLrc,
      isFavorite: isFavorite  ?? this.isFavorite,
      addedAt: addedAt,
      playCount:  playCount   ?? this.playCount,
    );
  }
}
