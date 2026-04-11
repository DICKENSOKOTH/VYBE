// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../player/mini_player.dart';
import '../player/now_playing_screen.dart';
import '../library/library_screen.dart';
import '../playlists/playlists_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex        = ref.watch(bottomNavIndexProvider);
    final isPlayerExpanded = ref.watch(playerExpandedProvider);
    final currentTrack    = ref.watch(currentTrackProvider);

    // 3 tabs: Library | Playlists | Settings (Search removed — inline in library)
    const screens = [LibraryScreen(), PlaylistsScreen(), SettingsScreen()];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (isPlayerExpanded) {
          ref.read(playerExpandedProvider.notifier).state = false;
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: VybeColors.background,
        body: Stack(
          children: [
            screens[navIndex],
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (currentTrack != null) const MiniPlayer(),
                _BottomNav(
                  currentIndex: navIndex,
                  onTap: (i) => ref.read(bottomNavIndexProvider.notifier).state = i,
                ),
              ]),
            ),
            if (isPlayerExpanded)
              const Positioned.fill(child: NowPlayingScreen()),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex:        currentIndex,
      onDestinationSelected: onTap,
      backgroundColor:      VybeColors.background,
      surfaceTintColor:     Colors.transparent,
      indicatorColor:       VybeColors.vybeStart.withAlpha(38),
      height:               64,
      destinations: const [
        NavigationDestination(
          icon:         Icon(Icons.library_music_outlined),
          selectedIcon: Icon(Icons.library_music_rounded),
          label: 'Library',
        ),
        NavigationDestination(
          icon:         Icon(Icons.queue_music_outlined),
          selectedIcon: Icon(Icons.queue_music_rounded),
          label: 'Playlists',
        ),
        NavigationDestination(
          icon:         Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }
}
