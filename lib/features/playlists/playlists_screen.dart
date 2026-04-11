// lib/features/playlists/playlists_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../data/models/playlist.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      backgroundColor: VybeColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Row(children: [
              const Text('Playlists',
                style: TextStyle(fontFamily: 'VybeDisplay', fontSize: 26,
                    fontWeight: FontWeight.w700, color: VybeColors.textPrimary,
                    letterSpacing: -0.4)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showCreateDialog(context, ref),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: VybeColors.vybeGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: playlistsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart))),
              error: (e, _) => Center(child: Text(e.toString(),
                  style: const TextStyle(color: VybeColors.textTertiary))),
              data: (playlists) {
                if (playlists.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ShaderMask(
                        shaderCallback: (b) => VybeColors.vybeGradient.createShader(b),
                        child: const Icon(Icons.queue_music_rounded,
                            color: Colors.white, size: 56)),
                      const SizedBox(height: 16),
                      const Text('No playlists yet',
                        style: TextStyle(fontFamily: 'VybeDisplay', fontSize: 20,
                            fontWeight: FontWeight.w700, color: VybeColors.textPrimary)),
                      const SizedBox(height: 8),
                      const Text('Tap + to create your first playlist',
                        style: TextStyle(fontFamily: 'VybeSans',
                            fontSize: 13, color: VybeColors.textTertiary)),
                    ]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: playlists.length,
                  itemBuilder: (ctx, i) => _PlaylistTile(
                    key: ValueKey(playlists[i].id),
                    playlist: playlists[i],
                    index: i,
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VybeColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Playlist',
          style: TextStyle(fontFamily: 'VybeSans', fontSize: 16,
              fontWeight: FontWeight.w600, color: VybeColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontFamily: 'VybeSans', color: VybeColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: VybeColors.textTertiary),
            border: UnderlineInputBorder(
                borderSide: BorderSide(color: VybeColors.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: VybeColors.vybeStart)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: VybeColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(playlistRepoProvider).create(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Create',
              style: const TextStyle(fontFamily: 'VybeSans',
                  fontWeight: FontWeight.w600).copyWith(color: VybeColors.vybeStart)),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTile extends ConsumerStatefulWidget {
  final VybePlaylist playlist;
  final int index;
  const _PlaylistTile({super.key, required this.playlist, required this.index});
  @override
  ConsumerState<_PlaylistTile> createState() => _PlaylistTileState();
}

class _PlaylistTileState extends ConsumerState<_PlaylistTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac    = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fade  = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    _slide = Tween(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 20) * 30), () {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Dismissible(
          key: ValueKey(widget.playlist.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: VybeColors.error.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: VybeColors.error, size: 22),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: VybeColors.surfaceElevated,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Delete Playlist',
                  style: TextStyle(fontFamily: 'VybeSans', fontSize: 16,
                      fontWeight: FontWeight.w600, color: VybeColors.textPrimary)),
                content: Text('Delete "${widget.playlist.name}"?',
                  style: const TextStyle(color: VybeColors.textSecondary)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel', style: TextStyle(color: VybeColors.textTertiary))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete', style: TextStyle(color: VybeColors.error))),
                ],
              ),
            ) ?? false;
          },
          onDismissed: (_) =>
              ref.read(playlistRepoProvider).delete(widget.playlist.id),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlaylistDetailScreen(playlist: widget.playlist),
            )),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: VybeColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VybeColors.border, width: 0.5),
              ),
              child: Row(children: [
                // Cover art placeholder
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        VybeColors.vybeStart.withAlpha(80),
                        VybeColors.vybeDeep.withAlpha(80),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.queue_music_rounded,
                      color: Colors.white54, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.playlist.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'VybeSans', fontSize: 15,
                        fontWeight: FontWeight.w600, color: VybeColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('${widget.playlist.trackCount} songs',
                    style: const TextStyle(fontFamily: 'VybeSans',
                        fontSize: 12, color: VybeColors.textTertiary)),
                ])),
                const Icon(Icons.chevron_right_rounded,
                    color: VybeColors.textTertiary, size: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
