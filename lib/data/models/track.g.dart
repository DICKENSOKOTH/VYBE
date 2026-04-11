// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
part of 'track.dart';

class TrackAdapter extends TypeAdapter<Track> {
  @override
  final int typeId = 0;

  @override
  Track read(BinaryReader reader) {
    final n  = reader.readByte();
    final f  = <int, dynamic>{for (int i = 0; i < n; i++) reader.readByte(): reader.read()};
    return Track(
      id:          f[0]  as String,
      title:       f[1]  as String,
      artist:      f[2]  as String,
      album:       f[3]  as String,
      albumArtUri: f[4]  as String?,
      localPath:   f[5]  as String?,
      streamUrl:   f[6]  as String?,
      originalUrl: f[7]  as String?,
      durationMs:  f[8]  as int,
      bitrate:     f[9]  as int?,
      sampleRate:  f[10] as int?,
      bitDepth:    f[11] as int?,
      codec:       f[12] as String?,
      sourceType:  f[13] as String,
      lyricsLrc:   f[14] as String?,
      isFavorite:  f[15] as bool,
      addedAt:     f[16] as DateTime?,
      playCount:   f[17] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Track obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.title)
      ..writeByte(2)..write(obj.artist)
      ..writeByte(3)..write(obj.album)
      ..writeByte(4)..write(obj.albumArtUri)
      ..writeByte(5)..write(obj.localPath)
      ..writeByte(6)..write(obj.streamUrl)
      ..writeByte(7)..write(obj.originalUrl)
      ..writeByte(8)..write(obj.durationMs)
      ..writeByte(9)..write(obj.bitrate)
      ..writeByte(10)..write(obj.sampleRate)
      ..writeByte(11)..write(obj.bitDepth)
      ..writeByte(12)..write(obj.codec)
      ..writeByte(13)..write(obj.sourceType)
      ..writeByte(14)..write(obj.lyricsLrc)
      ..writeByte(15)..write(obj.isFavorite)
      ..writeByte(16)..write(obj.addedAt)
      ..writeByte(17)..write(obj.playCount);
  }

  @override int get hashCode => typeId.hashCode;
  @override bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
