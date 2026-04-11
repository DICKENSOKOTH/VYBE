// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers.dart';
import 'features/home/home_screen.dart';

class VybeApp extends ConsumerStatefulWidget {
  const VybeApp({super.key});
  @override
  ConsumerState<VybeApp> createState() => _VybeAppState();
}

class _VybeAppState extends ConsumerState<VybeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioEngineProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VYBE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
