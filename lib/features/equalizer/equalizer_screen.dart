// lib/features/equalizer/equalizer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/vybe_audio_engine.dart';
import '../../core/providers.dart';
import '../../core/theme/vybe_colors.dart';

// ─── EQ Presets ────────────────────────────────────────────────────────────────
// All values in dB. Must stay within ±15 dB (typical Android hardware range).

const _presets = <String, List<double>>{
  'Flat':       [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Default':    [4, 3, 1.5, 0, 0, 0, 1, 2, 2.5, 3], // matches enhancedEqDefaultGains
  'Bass Boost': [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
  'Treble':     [0, 0, 0, 0, 0, 2, 3, 4, 5, 6],
  'Vocal':      [-2, -1, 0, 3, 4, 4, 3, 1, 0, -1],
  'Rock':       [4, 3, 2, 0, -1, 0, 2, 3, 4, 4],
  'Jazz':       [3, 2, 1, 2, 0, 0, 1, 2, 2, 3],
  'Electronic': [5, 4, 2, 0, -1, 0, 2, 3, 3, 4],
  'Hip-Hop':    [5, 4, 2, 1, 0, 0, -1, 1, 2, 2],
};

// Standard frequency labels — used as fallback if device params not available.
const _defaultFreqLabels = [
  '31Hz', '63Hz', '125Hz', '250Hz', '500Hz',
  '1K', '2K', '4K', '8K', '16K',
];

class EqBottomSheet extends ConsumerStatefulWidget {
  const EqBottomSheet({super.key});
  @override
  ConsumerState<EqBottomSheet> createState() => _EqBottomSheetState();
}

class _EqBottomSheetState extends ConsumerState<EqBottomSheet> {
  List<double> _gains       = List<double>.from(enhancedEqDefaultGains);
  double       _minDb       = -15.0;
  double       _maxDb       = 15.0;
  List<String> _freqLabels  = List<String>.from(_defaultFreqLabels);
  String?      _selectedPreset;
  bool         _loading     = true;

  @override
  void initState() {
    super.initState();
    _loadParams();
  }

  @override
  void didUpdateWidget(EqBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when the widget rebuilds (e.g., on mode change)
    _loadParams();
  }

  Future<void> _loadParams() async {
    final engine = ref.read(audioEngineProvider);

    // Read gains the engine is currently applying (tracked in memory)
    final tracked = engine.currentEqGains;

    // Read hardware metadata (band frequencies + range)
    try {
      final params = await engine.getEqualizerParameters();
      if (!mounted) return;

      if (params != null && params.bands.isNotEmpty) {
        final freqs = <String>[];
        for (final b in params.bands) {
          freqs.add(_fmtHz(b.centerFrequency));
        }
        // FIX: read the actual hardware gain range from the parameters object.
        // Previously minDb and maxDb were declared as local variables but never
        // assigned from params, so the slider always used the ±15 dB fallback
        // even when the device reported a different range (e.g. ±6 dB or ±12 dB).
        // This caused presets to silently clamp or exceed the real hardware range.
        final minDb = params.minDecibels;
        final maxDb = params.maxDecibels;
        setState(() {
          _gains = List<double>.from(tracked);
          _freqLabels = freqs;
          _minDb = minDb;
          _maxDb = maxDb;
          _loading = false;
        });
      } else {
        setState(() {
          _gains = List<double>.from(tracked);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gains = List<double>.from(tracked);
          _loading = false;
        });
      }
    }
  }

  String _fmtHz(double hz) =>
      hz >= 1000 ? '${(hz / 1000).round()}K' : '${hz.round()}Hz';

  Future<void> _applyPreset(String name, List<double> preset) async {
    final engine = ref.read(audioEngineProvider);
    // Clamp to device hardware range
    final gains = preset.map((g) => g.clamp(_minDb, _maxDb)).toList();
    await engine.applyEqGains(gains);
    if (!mounted) return;
    setState(() { _gains = gains; _selectedPreset = name; });
  }

  Future<void> _setBand(int i, double gain) async {
    final clamped = gain.clamp(_minDb, _maxDb);
    await ref.read(audioEngineProvider).setEqualizerBandGain(i, clamped);
    if (!mounted) return;
    setState(() { _gains[i] = clamped; _selectedPreset = null; });
  }

  @override
  Widget build(BuildContext context) {
    final dspMode    = ref.watch(dspModeProvider);  // Watch for changes
    final isEnhanced = dspMode == DspMode.enhanced;
    final screenH    = MediaQuery.of(context).size.height;

    // Rebuild UI immediately when dspMode changes
    return Container(
      height: screenH * 0.72,
      decoration: const BoxDecoration(
        color: VybeColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Drag handle ──────────────────────────────────────────────────────
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: VybeColors.textTertiary,
              borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // ── Header ────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            const Text('Equalizer', style: TextStyle(
              fontFamily: 'VybeDisplay', fontSize: 20,
              fontWeight: FontWeight.w700, color: VybeColors.textPrimary)),
            const Spacer(),
            // Show a pill if EQ is not active
            if (!isEnhanced)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: VybeColors.warning.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: VybeColors.warning.withAlpha(77)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline_rounded,
                      color: VybeColors.warning, size: 13),
                  SizedBox(width: 4),
                  Text('Enhanced mode only',
                    style: TextStyle(fontFamily: 'VybeSans',
                        fontSize: 11, color: VybeColors.warning)),
                ]),
              ),
          ]),
        ),

        const SizedBox(height: 12),

        // ── Presets ───────────────────────────────────────────────────────────
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _presets.entries.map((e) {
              final isSelected = _selectedPreset == e.key;
              return GestureDetector(
                onTap: isEnhanced ? () => _applyPreset(e.key, e.value) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? VybeColors.vybeStart.withAlpha(38)
                        : VybeColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? VybeColors.vybeStart.withAlpha(120)
                          : VybeColors.border,
                      width: isSelected ? 1.0 : 0.5,
                    ),
                  ),
                  child: Text(e.key, style: TextStyle(
                    fontFamily: 'VybeSans', fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? VybeColors.vybeStart
                        : (isEnhanced ? VybeColors.textSecondary : VybeColors.textTertiary),
                  )),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 10),
        const Divider(color: VybeColors.border, height: 1, thickness: 0.5),

        // ── Band sliders ──────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(VybeColors.vybeStart),
                  strokeWidth: 2))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
                  itemCount: _gains.length,
                  itemBuilder: (_, i) {
                    final label = i < _freqLabels.length ? _freqLabels[i] : '?';
                    final gain  = i < _gains.length ? _gains[i] : 0.0;
                    return _BandRow(
                      label:     label,
                      gain:      gain,
                      minDb:     _minDb,
                      maxDb:     _maxDb,
                      enabled:   isEnhanced,
                      onChanged: (g) => _setBand(i, g),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─── Single Band Row ─────────────────────────────────────────────────────────

class _BandRow extends StatelessWidget {
  final String label;
  final double gain;
  final double minDb;
  final double maxDb;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandRow({
    required this.label,
    required this.gain,
    required this.minDb,
    required this.maxDb,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final display = gain.clamp(minDb, maxDb);
    final sign    = display >= 0 ? '+' : '';
    // Colour: pink for boost, cyan for cut, grey when disabled
    final activeColor = enabled
        ? (display >= 0 ? VybeColors.vybeStart : VybeColors.tierHiRes)
        : VybeColors.textTertiary;

    return SizedBox(
      height: 46,
      child: Row(children: [
        // Frequency label
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(label,
              style: const TextStyle(fontFamily: 'VybeSans',
                  fontSize: 10, color: VybeColors.textTertiary)),
          ),
        ),
        // Slider
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   activeColor,
              inactiveTrackColor: VybeColors.surfaceGlass,
              thumbColor:         enabled ? Colors.white : VybeColors.textTertiary,
              overlayColor:       VybeColors.vybeStart.withAlpha(40),
              trackHeight:        3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: display,
              min: minDb, max: maxDb,
              // Snap to 0 if within 0.5 dB — makes flat easier to hit
              onChanged: enabled
                  ? (v) => onChanged(v.abs() < 0.5 ? 0.0 : v)
                  : null,
            ),
          ),
        ),
        // Gain value label
        SizedBox(
          width: 48,
          child: Text(
            '$sign${display.toStringAsFixed(1)}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'VybeSans', fontSize: 11,
              fontWeight: FontWeight.w600,
              color: display.abs() > 0.1 && enabled
                  ? activeColor
                  : VybeColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ]),
    );
  }
}