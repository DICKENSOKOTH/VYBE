// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
part of 'playlist.dart';

class VybePlaylistAdapter extends TypeAdapter<VybePlaylist> {
  @override
  final int typeId = 1;

  @override
  VybePlaylist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VybePlaylist(
      id:         fields[0] as String,
      name:       fields[1] as String,
      trackIds:   (fields[2] as List).cast<String>(),
      createdAt:  fields[3] as DateTime,
      updatedAt:  fields[4] as DateTime,
      coverArtUri: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, VybePlaylist obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)..write(obj.id)
      ..writeByte(1)..write(obj.name)
      ..writeByte(2)..write(obj.trackIds)
      ..writeByte(3)..write(obj.createdAt)
      ..writeByte(4)..write(obj.updatedAt)
      ..writeByte(5)..write(obj.coverArtUri);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VybePlaylistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
