// lib/data/repositories/playlist_repo.dart
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist.dart';

class PlaylistRepository {
  static const _boxName = 'playlists';
  static const _uuid = Uuid();

  Box<VybePlaylist> get _box => Hive.box<VybePlaylist>(_boxName);

  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<VybePlaylist>(_boxName);
    }
  }

  List<VybePlaylist> getAll() {
    return _box.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  ValueListenable<Box<VybePlaylist>> listenable() => _box.listenable();

  Future<VybePlaylist> create(String name) async {
    final now = DateTime.now();
    final playlist = VybePlaylist(
      id: _uuid.v4(),
      name: name.trim(),
      trackIds: [],
      createdAt: now,
      updatedAt: now,
    );
    await _box.put(playlist.id, playlist);
    return playlist;
  }

  Future<void> rename(String id, String newName) async {
    final pl = _box.get(id);
    if (pl == null) return;
    pl.name = newName.trim();
    pl.updatedAt = DateTime.now();
    await pl.save();
  }

  Future<void> delete(String id) async => _box.delete(id);

  Future<void> addTrack(String playlistId, String trackId) async {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    if (!pl.trackIds.contains(trackId)) {
      pl.trackIds = [...pl.trackIds, trackId];
      pl.updatedAt = DateTime.now();
      await pl.save();
    }
  }

  Future<void> removeTrack(String playlistId, String trackId) async {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    pl.trackIds = pl.trackIds.where((id) => id != trackId).toList();
    pl.updatedAt = DateTime.now();
    await pl.save();
  }

  Future<void> reorderTrack(String playlistId, int oldIndex, int newIndex) async {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    final ids = [...pl.trackIds];
    final item = ids.removeAt(oldIndex);
    ids.insert(newIndex, item);
    pl.trackIds = ids;
    pl.updatedAt = DateTime.now();
    await pl.save();
  }

  Future<void> setCoverArt(String playlistId, String? artUri) async {
    final pl = _box.get(playlistId);
    if (pl == null) return;
    pl.coverArtUri = artUri;
    await pl.save();
  }
}
