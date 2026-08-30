import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/util/format.dart';
import 'recorder_controller.dart';

/// Stala z makiety: parametry nagrania pokazywane pod licznikiem.
const _formatCaption = 'm4a · aacLc · 64 kbps · mono';

/// Rozmiary przepisane 1:1 z designu (ekran "Nagrywaj 1a").
const _pulseBoxSize = 280.0;
const _blobSize = 168.0;
const _barCount = 9;
const _barWidth = 6.0;
const _barsHeight = 56.0;

/// Czasy animacji z sekcji styli designu. Jeden kontroler o okresie [_morphPeriod] napedza
/// wszystko; pozostale elementy dostaja swoja faze przez modulo, zeby nie mnozyc tickerow.
const _morphPeriod = Duration(seconds: 6);
const _ring1Seconds = 2.0;
const _ring2Seconds = 2.4;

/// `animation:bar <czas>s ... <opoznienie>s` dla dziewieciu slupkow z makiety.
const _barSeconds = <double>[1.1, 0.9, 1.3, 1.0, 1.2, 0.95, 1.15, 1.05, 1.25];
const _barDelays = <double>[-0.9, -0.2, -0.5, 0.0, -0.7, -0.35, -0.15, -0.6, -0.85];

class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: _morphPeriod)..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Oscylacja 0 -> 1 -> 0 o ksztalcie ease-in-out, jak `ease-in-out` w keyframe'ach CSS.
  double _wave(double phase) => (1 - math.cos(2 * math.pi * phase)) / 2;

  double _phase(double seconds, [double delay = 0]) {
    final periods = _morphPeriod.inMilliseconds / 1000 / seconds;
    return (_pulse.value * periods - delay / seconds) % 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recorderControllerProvider);
    final controller = ref.read(recorderControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mikro'),
        titleTextStyle: const TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w500),
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surface,
        actions: [
          // W makiecie to statyczna ikona bez akcji — patrz raport.
          SizedBox(
            width: 48,
            height: 48,
            child: Icon(Symbols.history, fill: 1, size: 24, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 160),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatusPill(isRecording: state.isRecording),
                const SizedBox(height: 28),
                _Timer(elapsed: state.elapsed, isRecording: state.isRecording),
                Text(
                  _formatCaption,
                  style: TextStyle(
                    fontSize: 13,
                    height: 18 / 13,
                    letterSpacing: 0.4,
                    fontFamily: 'monospace',
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 44),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => _PulseButton(
                    isRecording: state.isRecording,
                    amplitude: state.amplitude,
                    ring1: _wave(_phase(_ring1Seconds)),
                    ring2: _wave(_phase(_ring2Seconds)),
                    morph: _wave(_pulse.value),
                    onTap: () => _toggle(controller, state.isRecording),
                  ),
                ),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => _LevelBars(
                    isRecording: state.isRecording,
                    amplitude: state.amplitude,
                    phases: [
                      for (var i = 0; i < _barCount; i++)
                        _wave(_phase(_barSeconds[i], _barDelays[i])),
                    ],
                  ),
                ),
                if (state.lastError != null) ...[
                  const SizedBox(height: 32),
                  _ErrorCard(message: state.lastError!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(RecorderController controller, bool isRecording) async {
    if (!isRecording) {
      await controller.startRecording();
      return;
    }
    await controller.stopRecording();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: scheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      content: Text(
        'Nagranie zapisane — transkrypcja w toku.',
        style: TextStyle(fontSize: 14, color: scheme.onInverseSurface),
      ),
    ));
  }
}

/// Pigulka stanu nad licznikiem: czerwona kropka + "Nagrywanie" w trakcie, neutralna
/// "Gotowy do nagrywania" w spoczynku.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = isRecording ? 'Nagrywanie' : 'Gotowy do nagrywania';
    return Container(
      height: 32,
      padding: EdgeInsets.only(left: isRecording ? 12 : 14, right: isRecording ? 14 : 14),
      decoration: BoxDecoration(
        color: isRecording ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              color: isRecording ? scheme.onErrorContainer : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Timer extends StatelessWidget {
  const _Timer({required this.elapsed, required this.isRecording});

  final Duration elapsed;
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      formatDuration(elapsed),
      style: TextStyle(
        fontSize: 76,
        height: 80 / 76,
        fontWeight: FontWeight.w700,
        letterSpacing: -2,
        // Cyfry o stalej szerokosci, zeby licznik nie drgal przy kazdej sekundzie.
        fontFeatures: const [FontFeature.tabularFigures()],
        color: isRecording
            ? scheme.onSurface
            : scheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

/// Wielki przycisk z pulsem. W trakcie nagrania dwa pierscienie oddychaja, a plama morfuje
/// ksztalt; w spoczynku zostaje spokojny okrag w cienkiej obwodce.
class _PulseButton extends StatelessWidget {
  const _PulseButton({
    required this.isRecording,
    required this.amplitude,
    required this.ring1,
    required this.ring2,
    required this.morph,
    required this.onTap,
  });

  final bool isRecording;
  final double amplitude;
  final double ring1;
  final double ring2;
  final double morph;
  final VoidCallback onTap;

  /// Amplituda moduluje rozmach pulsu, ale go nie gasi — przy ciszy ruch jest ledwie widoczny,
  /// przy glosnym dzwieku pelny, jak w makiecie.
  double get _gain => 0.35 + 0.65 * amplitude.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: _pulseBoxSize,
      height: _pulseBoxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isRecording) ...[
            // ring2: inset 0, scale 1.05 -> 1.28, opacity .3 -> .1
            _Ring(
              inset: 0,
              color: scheme.primaryContainer,
              scale: 1.05 + (1.28 - 1.05) * ring2 * _gain,
              opacity: 0.30 + (0.10 - 0.30) * ring2,
            ),
            // ring1: inset 28, scale 1 -> 1.14, opacity .55 -> .28
            _Ring(
              inset: 28,
              color: scheme.secondaryContainer,
              scale: 1.0 + (1.14 - 1.0) * ring1 * _gain,
              opacity: 0.55 + (0.28 - 0.55) * ring1,
            ),
          ] else
            Container(
              width: _pulseBoxSize - 2 * 56,
              height: _pulseBoxSize - 2 * 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: _blobSize,
              height: _blobSize,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: isRecording
                    ? _morphRadius(morph)
                    : const BorderRadius.all(Radius.circular(_blobSize / 2)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Symbols.stop : Symbols.mic,
                fill: 1,
                size: 64,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Przeklad `@keyframes morph` z designu. CSS podaje promienie jako procenty szerokosci
  /// i wysokosci osobno (`44% 56% 52% 48% / 50% 44% 56% 50%`), wiec kazdy naroznik jest
  /// elipsa, a nie okregiem — stad Radius.elliptical.
  BorderRadius _morphRadius(double t) {
    const from = [
      [0.44, 0.50],
      [0.56, 0.44],
      [0.52, 0.56],
      [0.48, 0.50],
    ];
    const to = [
      [0.56, 0.44],
      [0.44, 0.56],
      [0.46, 0.44],
      [0.54, 0.56],
    ];
    Radius corner(int i) => Radius.elliptical(
          _blobSize * (from[i][0] + (to[i][0] - from[i][0]) * t),
          _blobSize * (from[i][1] + (to[i][1] - from[i][1]) * t),
        );
    return BorderRadius.only(
      topLeft: corner(0),
      topRight: corner(1),
      bottomRight: corner(2),
      bottomLeft: corner(3),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.inset,
    required this.color,
    required this.scale,
    required this.opacity,
  });

  final double inset;
  final Color color;
  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final size = _pulseBoxSize - 2 * inset;
    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Dziewiec slupkow poziomu. W spoczynku sa kropkami, w trakcie nagrania skacza — kazdy
/// z wlasnym okresem i przesunieciem faz, dokladnie jak w makiecie.
class _LevelBars extends StatelessWidget {
  const _LevelBars({
    required this.isRecording,
    required this.amplitude,
    required this.phases,
  });

  final bool isRecording;
  final double amplitude;
  final List<double> phases;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gain = 0.25 + 0.75 * amplitude.clamp(0.0, 1.0);
    return SizedBox(
      height: _barsHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            isRecording ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _barCount; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: _barWidth,
              // `@keyframes bar` skaluje wysokosc od .25 do 1; amplituda przycina zakres.
              height: isRecording
                  ? _barsHeight * (0.25 + 0.75 * phases[i]) * gain
                  : _barWidth,
              decoration: BoxDecoration(
                color: isRecording ? scheme.primary : scheme.outlineVariant,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Karta bledu z sekcji "Stany puste i błędy".
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(Symbols.mic_off, fill: 1, size: 24, color: scheme.error),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
