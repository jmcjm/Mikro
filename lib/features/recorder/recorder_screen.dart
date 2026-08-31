import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_collection/m3e_collection.dart' hide Cubic;
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../l10n/app_localizations.dart';
import '../shell/home_tab.dart';
import 'recorder_controller.dart';

/// Stała z makiety: parametry nagrania pokazywane pod licznikiem.
const _formatCaption = 'm4a · aacLc · 64 kbps · mono';

/// Rozmiary przepisane 1:1 z designu (ekran "Nagrywaj 1a" MD3 Expressive).
const _pulseBoxSize = 280.0;
const _readyBlobSize = 168.0;
const _recordingBlobSize = 190.0;
const _barCount = 9;
const _barWidth = 6.0;
const _barsHeight = 56.0;

/// Czasy animacji z sekcji styli designu:
/// - Stop = 9-płatkowe cookie 190 dp, obrót 22 s/obrót (16°/s) i oddech ±4,5% (okres 2,8 s).
/// - Pierścienie pulsu: 2,0 s (wewnętrzny) i 2,4 s (zewnętrzny).
const _spinSeconds = 22.0;
const _cookiePulseSeconds = 2.8;
const _ring1Seconds = 2.0;
const _ring2Seconds = 2.4;

/// `animation:bar <czas>s ... <opoznienie>s` dla dziewięciu słupków z makiety.
const _barSeconds = <double>[1.1, 0.9, 1.3, 1.0, 1.2, 0.95, 1.15, 1.05, 1.25];
const _barDelays = <double>[-0.9, -0.2, -0.5, 0.0, -0.7, -0.35, -0.15, -0.6, -0.85];

/// Faza cyklu w [0, 1) dla elementu o okresie [periodSeconds], przesunięta o [delaySeconds].
double phaseAt(double elapsedSeconds, double periodSeconds, [double delaySeconds = 0]) =>
    ((elapsedSeconds - delaySeconds) / periodSeconds) % 1.0;

class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});

  @override
  ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends ConsumerState<RecorderScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  late final AnimationController _morphController;
  late final Animation<double> _morphAnimation;
  Timer? _snackBarTimer;

  /// Czas trwania przejścia koło ⇄ cookie 9 (650 ms).
  static const _morphDuration = Duration(milliseconds: 650);

  /// Czas od startu bieżącego nagrania. ValueNotifier, a nie zwykłe pole z setState, bo dzięki
  /// niemu co klatkę przebudowują się wyłącznie animowane poddrzewa, a nie cały ekran.
  final ValueNotifier<double> _elapsedSeconds = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _morphController = AnimationController(
      vsync: this,
      duration: _morphDuration,
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      reverseCurve: const Cubic(0.2, 0.0, 0.0, 1.0).flipped,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed &&
            !ref.read(recorderControllerProvider).isRecording) {
          _ticker.stop();
          _elapsedSeconds.value = 0;
        }
      });
  }

  @override
  void dispose() {
    _snackBarTimer?.cancel();
    _ticker.dispose();
    _morphController.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) =>
      _elapsedSeconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  /// Włącza puls na czas nagrania i uruchamia morfing w przód.
  /// Po zatrzymaniu nagrania morfing wraca w tył (cookie 9 -> koło) w 650 ms.
  void _syncTicker(bool isRecording) {
    if (isRecording) {
      if (!_ticker.isActive) _ticker.start();
      _morphController.forward();
    } else {
      _morphController.reverse();
    }
  }

  /// W trakcie nagrania lub podczas aktywnej animacji powrotnej odświeżamy widgety co klatkę.
  Widget _animated(bool animate, Widget Function() builder) =>
      (animate || _morphController.value > 0)
          ? AnimatedBuilder(
              animation: Listenable.merge([_elapsedSeconds, _morphController]),
              builder: (_, _) => builder(),
            )
          : builder();

  /// Oscylacja 0 -> 1 -> 0 o kształcie ease-in-out, jak `ease-in-out` w keyframe'ach CSS.
  double _wave(double phase) => (1 - math.cos(2 * math.pi * phase)) / 2;

  double _phase(double seconds, [double delay = 0]) =>
      phaseAt(_elapsedSeconds.value, seconds, delay);

  @override
  Widget build(BuildContext context) {
    ref.listen<RecorderState>(recorderControllerProvider, (previous, next) {
      if (previous?.isRecording != next.isRecording) _syncTicker(next.isRecording);
    });

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
          IconButton(
            onPressed: () => ref.read(homeTabProvider.notifier).select(HomeTab.library),
            tooltip: AppLocalizations.of(context).recorderHistoryTooltip,
            iconSize: 24,
            icon: Icon(Symbols.history_rounded, fill: 1, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
                        fontFamily: monoFontFamily,
                        fontFamilyFallback: monoFontFallback,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 44),
                    _animated(
                      state.isRecording,
                      () => _PulseButton(
                        isRecording: state.isRecording,
                        morphProgress: _morphAnimation.value,
                        amplitude: state.amplitude,
                        ring1: _wave(_phase(_ring1Seconds)),
                        ring2: _wave(_phase(_ring2Seconds)),
                        spinPhase: _phase(_spinSeconds),
                        cookiePulse: _wave(_phase(_cookiePulseSeconds)),
                        onTap: () => _toggle(controller, state.isRecording),
                      ),
                    ),
                    const SizedBox(height: 40),
                    _animated(
                      state.isRecording,
                      () => _LevelBars(
                        isRecording: state.isRecording,
                        amplitude: state.amplitude,
                        elapsedSeconds: _elapsedSeconds.value,
                      ),
                    ),
                    if (state.lastError != null) ...[
                      const SizedBox(height: 32),
                      _ErrorCard(error: state.lastError!),
                    ],
                  ],
                ),
              ),
            );
          },
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
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    _snackBarTimer?.cancel();
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: scheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      content: Text(
        l10n.recorderSavedSnackbar,
        style: TextStyle(fontSize: 14, color: scheme.onInverseSurface),
      ),
      action: SnackBarAction(
        label: l10n.recorderSavedAction,
        textColor: scheme.inversePrimary,
        onPressed: () {
          _snackBarTimer?.cancel();
          messenger.hideCurrentSnackBar();
          ref.read(homeTabProvider.notifier).select(HomeTab.library);
        },
      ),
    ));
    _snackBarTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        messenger.hideCurrentSnackBar();
      }
    });
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
    final l10n = AppLocalizations.of(context);
    final label = isRecording ? l10n.recorderStatusRecording : l10n.recorderStatusReady;
    return Container(
      height: 32,
      padding: EdgeInsets.only(left: isRecording ? 12 : 14, right: 14),
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

/// Przycisk nagrywania / zatrzymania w stylu MD3 Expressive.
///
/// W spoczynku (Gotowy do nagrywania):
/// - Koło 168 dp na `primary` z ikoną mikrofonu 64 dp na `onPrimary`,
/// - Zewnętrzny cienki obrys (średnica 168 dp) z `outlineVariant`.
///
/// W trakcie nagrywania:
/// - Płynny morfing 0..460 ms (koło -> 9-płatkowe cookie 190 dp z `MaterialShapes.cookie9Sided`),
/// - Dwa pierścienie pulsu (ring1: 2,0 s, ring2: 2,4 s) modulowane amplitudą,
/// - Obrót cookie 22 s / obrót (16°/s) liniowo w kółko,
/// - Oddech cookie ±4,5% w rytm amplitudy i cyklu 2,8 s (`animation: cookiepulse`),
/// - W środku przycisk zatrzymania ze stop-square (58 dp, promień 16 dp) stabilny w centrum.
class _PulseButton extends StatelessWidget {
  const _PulseButton({
    required this.isRecording,
    required this.morphProgress,
    required this.amplitude,
    required this.ring1,
    required this.ring2,
    required this.spinPhase,
    required this.cookiePulse,
    required this.onTap,
  });

  final bool isRecording;
  final double morphProgress;
  final double amplitude;
  final double ring1;
  final double ring2;
  final double spinPhase;
  final double cookiePulse;
  final VoidCallback onTap;

  /// Amplituda moduluje rozmach pulsu, ale go nie gasi — przy ciszy ruch jest ledwie widoczny,
  /// przy głośnym dźwięku pełny.
  double get _gain => 0.35 + 0.65 * amplitude.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentBlobSize =
        _readyBlobSize + (_recordingBlobSize - _readyBlobSize) * morphProgress;

    return SizedBox(
      width: _pulseBoxSize,
      height: _pulseBoxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isRecording) ...[
            _Ring(
              inset: 0,
              color: scheme.primaryContainer,
              scale: 1.05 + (1.28 - 1.05) * ring2 * _gain,
              opacity: (0.30 + (0.10 - 0.30) * ring2) * morphProgress,
            ),
            _Ring(
              inset: 28,
              color: scheme.secondaryContainer,
              scale: 1.0 + (1.14 - 1.0) * ring1 * _gain,
              opacity: (0.55 + (0.28 - 0.55) * ring1) * morphProgress,
            ),
          ],
          if (!isRecording || morphProgress < 1.0)
            Opacity(
              opacity: (1.0 - morphProgress).clamp(0.0, 1.0),
              child: Container(
                width: _pulseBoxSize - 2 * 56,
                height: _pulseBoxSize - 2 * 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: currentBlobSize,
              height: currentBlobSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Tło kształtu morfujące z obrotem i oddechem
                  Transform.scale(
                    scale: 1.0 + 0.045 * cookiePulse * _gain * morphProgress,
                    child: Transform.rotate(
                      angle: 2 * math.pi * spinPhase * morphProgress,
                      child: CustomPaint(
                        size: Size(currentBlobSize, currentBlobSize),
                        painter: _MorphShapePainter(
                          progress: morphProgress,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // Stabilna ikona w centrum
                  if (morphProgress < 0.5)
                    Opacity(
                      opacity: (1.0 - morphProgress * 2).clamp(0.0, 1.0),
                      child: Icon(
                        Symbols.mic_rounded,
                        fill: 1,
                        size: 64,
                        color: scheme.onPrimary,
                      ),
                    )
                  else
                    Opacity(
                      opacity: ((morphProgress - 0.5) * 2).clamp(0.0, 1.0),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: scheme.onPrimary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Symbols.stop_rounded,
                          fill: 1,
                          size: 58,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rysuje kształt morfujący między kołem a 9-płatkowym cookie MD3 Expressive.
class _MorphShapePainter extends CustomPainter {
  _MorphShapePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static final Morph _morph = Morph(
    MaterialShapes.circle,
    MaterialShapes.cookie9Sided,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final path = _morph.toPath(progress: progress.clamp(0.0, 1.0));
    final matrix = Matrix4.identity()..scale(size.width, size.height);
    final scaledPath = path.transform(matrix.storage);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(scaledPath, paint);
  }

  @override
  bool shouldRepaint(covariant _MorphShapePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
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

/// Dziewięć słupków poziomu dźwięku. W spoczynku są kropkami (6 dp), w trakcie nagrania
/// każdy słupek zachowuje się jak niezależne pasmo częstotliwości audio:
/// reaguje na poziom z mikrofonu oraz harmoniczne fale akustyczne, tworząc żywy,
/// naturalny korektor graficzny (zamiast sztywnego, symetrycznego trójkąta).
class _LevelBars extends StatelessWidget {
  const _LevelBars({
    required this.isRecording,
    required this.amplitude,
    required this.elapsedSeconds,
  });

  final bool isRecording;
  final double amplitude;
  final double elapsedSeconds;

  static const _barFreqs = <double>[0.9, 1.4, 0.8, 1.6, 1.1, 1.3, 0.7, 1.5, 1.0];
  static const _barPhases = <double>[0.0, 0.4, 0.8, 0.2, 0.6, 0.1, 0.5, 0.9, 0.3];
  static const _baseSensitivity = <double>[0.60, 0.75, 0.85, 0.80, 0.90, 0.82, 0.78, 0.72, 0.55];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final normAmp = amplitude.clamp(0.0, 1.0);

    return SizedBox(
      height: _barsHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            isRecording ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _barCount; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Builder(builder: (context) {
              final double height;
              if (!isRecording) {
                height = _barWidth;
              } else {
                final wave = 0.5 +
                    0.5 *
                        math.sin(2 *
                            math.pi *
                            (elapsedSeconds * _barFreqs[i] + _barPhases[i]));
                // Spokojniejszy, stonowany zakres modulacji pasma (0.60..1.0)
                final dynamicBand = 0.60 + 0.40 * wave;
                final dynamicGain = normAmp * dynamicBand * _baseSensitivity[i];
                // Stonowana maksymalna wysokość: naturalny, łagodny ruch
                height = (_barWidth + (_barsHeight - _barWidth) * dynamicGain * 0.75)
                    .clamp(_barWidth, _barsHeight);
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                width: _barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: isRecording ? scheme.primary : scheme.outlineVariant,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Karta bledu z sekcji "Stany puste i bledy".
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final RecorderError error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final message = switch (error.kind) {
      RecorderErrorKind.micPermission => l10n.recorderErrorMicPermission,
      RecorderErrorKind.startFailed => l10n.recorderErrorStartFailed(error.detail ?? ''),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          Icon(Symbols.mic_off_rounded, fill: 1, size: 24, color: scheme.error),
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
