// lib/data/models/playlist.dart
import 'package:hive/hive.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class VybePlaylist extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1)       String name;
  @HiveField(2)       List<String> trackIds;
  @HiveField(3) final DateTime createdAt;
  @HiveField(4)       DateTime updatedAt;
  @HiveField(5)       String? coverArtUri;

  VybePlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
    this.coverArtUri,
  });

  int get trackCount => trackIds.length;
}
