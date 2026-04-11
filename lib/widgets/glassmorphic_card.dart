// lib/widgets/glassmorphic_card.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/vybe_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;
  final double blurStrength;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const GlassCard({
    super.key, required this.child, this.width, this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin  = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.blurStrength   = 20,
    this.backgroundColor = VybeColors.surfaceGlass,
    this.borderColor     = VybeColors.border,
    this.borderWidth     = 0.5,
    this.onTap, this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width, height: height, margin: margin,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
            child: Container(
              decoration: BoxDecoration(
                gradient: gradient,
                color: gradient == null ? backgroundColor : null,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: borderWidth)),
              padding: padding, child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated waveform bars — VYBE logo identity element
class WaveformBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;
  final int barCount;
  final double barWidth;
  final double barSpacing;

  const WaveformBars({
    super.key, required this.isPlaying,
    this.color      = VybeColors.vybeStart,
    this.height     = 24,
    this.barCount   = 5,
    this.barWidth   = 3,
    this.barSpacing = 2,
  });

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars> with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;
  late List<Animation<double>>   _anims;

  static const _baseH  = [0.40, 0.70, 1.00, 0.60, 0.80];
  static const _speeds = [600,   400,  500,  350,  450];

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.barCount, (i) => AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _speeds[i % _speeds.length]),
    ));
    _anims = _ctrls.asMap().entries.map((e) {
      final base = _baseH[e.key % _baseH.length];
      return Tween(begin: base * 0.3, end: base).animate(
          CurvedAnimation(parent: e.value, curve: Curves.easeInOut));
    }).toList();
    if (widget.isPlaying) _start();
  }

  void _start() {
    for (int i = 0; i < _ctrls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  void _stop() {
    for (final c in _ctrls) { c.animateTo(0.3, duration: const Duration(milliseconds: 300)); }
  }

  @override
  void didUpdateWidget(WaveformBars old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _start() : _stop();
    }
  }

  @override
  void dispose() { for (final c in _ctrls) { c.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Container(
              width: widget.barWidth,
              height: widget.height * _anims[i].value,
              margin: EdgeInsets.only(
                  right: i < widget.barCount - 1 ? widget.barSpacing : 0),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(widget.barWidth / 2)),
            ),
          );
        }),
      ),
    );
  }
}
