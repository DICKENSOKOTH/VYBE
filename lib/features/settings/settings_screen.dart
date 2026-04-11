// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';
import '../../audio/vybe_audio_engine.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dspMode       = ref.watch(dspModeProvider);
    final geniusKey     = ref.watch(geniusApiKeyProvider);
    final anthropicKey  = ref.watch(anthropicApiKeyProvider);

    return Scaffold(
      backgroundColor: VybeColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 160),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            const Text('Settings',
              style: TextStyle(fontFamily: 'VybeDisplay', fontSize: 26,
                  fontWeight: FontWeight.w700, color: VybeColors.textPrimary,
                  letterSpacing: -0.4)),

            const SizedBox(height: 28),

            // ── Playback Engine ──────────────────────────────────────────────
            const _SectionHeader('PLAYBACK ENGINE'),
            const SizedBox(height: 6),
            const Text('Two audibly different modes. Applies immediately and persists.',
              style: TextStyle(fontFamily: 'VybeSans', fontSize: 12,
                  color: VybeColors.textTertiary)),
            const SizedBox(height: 12),

            _EngineCard(
              icon: Icons.graphic_eq_rounded,
              label: 'Transparent',
              badge: 'LOSSLESS',
              badgeColor: VybeColors.tierHiRes,
              description: 'Zero processing. Raw decoded PCM delivered directly — '
                  'exactly what the mastering engineer intended. '
                  'Essential for FLAC, WAV, and ALAC.',
              accentColor: VybeColors.tierHiRes,
              isSelected: dspMode == DspMode.transparent,
              onTap: () {
                ref.read(dspModeProvider.notifier).state = DspMode.transparent;
                ref.read(audioEngineProvider).setDspMode(DspMode.transparent);
              },
            ),

            const SizedBox(height: 10),

            _EngineCard(
              icon: Icons.equalizer_rounded,
              label: 'Enhanced',
              badge: null,
              badgeColor: VybeColors.vybeStart,
              description: 'Warm loudness curve: boosted sub-bass, bass warmth, '
                  'presence, and air. +3 dB loudness. '
                  'Transforms MP3 and AAC into something that punches.',
              accentColor: VybeColors.vybeStart,
              isSelected: dspMode == DspMode.enhanced,
              onTap: () {
                ref.read(dspModeProvider.notifier).state = DspMode.enhanced;
                ref.read(audioEngineProvider).setDspMode(DspMode.enhanced);
              },
            ),

            const SizedBox(height: 28),

            // ── Lyrics Sources ───────────────────────────────────────────────
            const _SectionHeader('LYRICS SOURCES'),
            const SizedBox(height: 6),
            const Text('LRCLIB is free and active by default (synced lyrics). '
                'Add Genius for a larger catalogue.',
              style: TextStyle(fontFamily: 'VybeSans', fontSize: 12,
                  color: VybeColors.textTertiary)),
            const SizedBox(height: 12),

            _ApiKeyField(
              icon: Icons.lyrics_rounded,
              label: 'Genius API Key',
              hint: 'Paste your Genius client access token',
              initialValue: geniusKey,
              onChanged: (v) => ref.read(geniusApiKeyProvider.notifier).state = v,
            ),

            const SizedBox(height: 10),

            _ApiKeyField(
              icon: Icons.auto_awesome_rounded,
              label: 'Anthropic Key (AI lyrics fallback)',
              hint: 'Optional — generates lyrics for obscure tracks',
              initialValue: anthropicKey,
              onChanged: (v) => ref.read(anthropicApiKeyProvider.notifier).state = v,
            ),

            const SizedBox(height: 28),

            // ── About ──────────────────────────────────────────────────────
            const _SectionHeader('ABOUT'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VybeColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VybeColors.border),
              ),
              child: Row(children: [
                ShaderMask(
                  shaderCallback: (b) => VybeColors.vybeGradient.createShader(b),
                  child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('VYBE', style: TextStyle(fontFamily: 'VybeDisplay',
                      fontSize: 16, fontWeight: FontWeight.w700, color: VybeColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('v1.0.0 — Feel Every Frequency',
                    style: TextStyle(fontFamily: 'VybeSans',
                        fontSize: 12, color: VybeColors.textTertiary)),
                ])),
              ]),
            ),

          ]),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontFamily: 'VybeSans', fontSize: 11,
        fontWeight: FontWeight.w600, color: VybeColors.textTertiary, letterSpacing: 2));
}

class _EngineCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color badgeColor;
  final String description;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;
  const _EngineCard({required this.icon, required this.label, required this.badge,
    required this.badgeColor, required this.description, required this.accentColor,
    required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withAlpha(18) : VybeColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor.withAlpha(120) : VybeColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 20, height: 20, margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? accentColor : VybeColors.textTertiary,
                width: isSelected ? 5.5 : 1.5,
              ),
              color: isSelected ? Colors.white : Colors.transparent,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(isSelected ? 38 : 20),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label, style: TextStyle(fontFamily: 'VybeSans', fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? accentColor : VybeColors.textPrimary)),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(38), borderRadius: BorderRadius.circular(6)),
                  child: Text(badge!, style: TextStyle(fontFamily: 'VybeSans', fontSize: 9,
                      fontWeight: FontWeight.w700, color: badgeColor, letterSpacing: 0.5)),
                ),
              ],
            ]),
            const SizedBox(height: 5),
            Text(description, style: const TextStyle(fontFamily: 'VybeSans',
                fontSize: 12, color: VybeColors.textTertiary, height: 1.4)),
          ])),
        ]),
      ),
    );
  }
}

class _ApiKeyField extends StatefulWidget {
  final IconData icon;
  final String label;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  const _ApiKeyField({required this.icon, required this.label, required this.hint,
    required this.initialValue, required this.onChanged});
  @override
  State<_ApiKeyField> createState() => _ApiKeyFieldState();
}

class _ApiKeyFieldState extends State<_ApiKeyField> {
  late TextEditingController _ctrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: VybeColors.surfaceElevated, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VybeColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(widget.icon, color: VybeColors.textTertiary, size: 16),
          const SizedBox(width: 8),
          Text(widget.label, style: const TextStyle(fontFamily: 'VybeSans',
              fontSize: 12, fontWeight: FontWeight.w500, color: VybeColors.textSecondary)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(
            controller: _ctrl,
            obscureText: _obscure,
            onChanged: widget.onChanged,
            style: const TextStyle(fontFamily: 'VybeSans',
                fontSize: 13, color: VybeColors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(fontFamily: 'VybeSans',
                  fontSize: 13, color: VybeColors.textTertiary),
              border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          )),
          GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: VybeColors.textTertiary, size: 18)),
        ]),
      ]),
    );
  }
}
