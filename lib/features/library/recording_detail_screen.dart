import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/audio/waveform.dart';
import '../../core/db/database.dart';
import '../../core/models/recording_status.dart';
import '../../core/models/tag_name.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../l10n/app_localizations.dart';
import 'library_styles.dart';
import 'playback.dart';
import 'recording_error.dart';
import 'selected_recording.dart';

/// Host container frame for recording details. Dictates top chrome and deletion navigation —
/// content is identical in both modes.
enum DetailChrome {
  /// Standalone route: app bar with back navigation, action buttons in top-right corner.
  screen,

  /// Right column of library in wide layouts: desktop mockup header without app bar or separate route.
  panel,
}

/// Fullscreen recording details. Thin wrapper around [RecordingDetailView] allowing
/// Navigator.push invocations without needing explicit frame configuration.
class RecordingDetailScreen extends StatelessWidget {
  const RecordingDetailScreen({super.key, required this.recordingId});

  final String recordingId;

  @override
  Widget build(BuildContext context) => RecordingDetailView(recordingId: recordingId);
}

class RecordingDetailView extends ConsumerStatefulWidget {
  const RecordingDetailView({
    super.key,
    required this.recordingId,
    this.chrome = DetailChrome.screen,
  });

  final String recordingId;
  final DetailChrome chrome;

  @override
  ConsumerState<RecordingDetailView> createState() => _RecordingDetailViewState();
}

class _RecordingDetailViewState extends ConsumerState<RecordingDetailView>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();

  /// Position from the last REAL player event (or seek). Between
  /// events the card interpolates smoothly — see [_publish].
  Duration _eventPosition = Duration.zero;
  Duration _total = Duration.zero;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Waveform animation ticker. Runs ONLY during active playback: no need to
  /// interpolate otherwise, avoiding unnecessary 60 FPS recalculations when idle.
  late final Ticker _ticker;

  /// Last ticker reading and its value when [_eventPosition] was captured.
  /// The difference represents elapsed time since the last event.
  Duration _tick = Duration.zero;
  Duration _baseTick = Duration.zero;

  /// Bar dance animation clock: shares elapsed time with position interpolation,
  /// but maintains a separate listenable so animation continues even when position is stationary
  /// (e.g. when position reaches end of track).
  final _beat = ValueNotifier<Duration>(Duration.zero);

  /// Waveform redraws on both position movement and bar dance beat; timestamps redraw on position only.
  late final Listenable _waveBeat = Listenable.merge([_shown, _beat]);

  /// Displayed position driving waveform and timestamp updates. Dedicated notifier instead of `setState`:
  /// animation frames rebuild only waveform and time indicators, not the full card or transcript.
  final _shown = ValueNotifier<Duration>(Duration.zero);

  /// Parsed waveform cached alongside the raw database string.
  /// Prevents reparsing the same JSON 60 times per second during animation frames.
  String? _waveformRaw;
  List<double>? _waveformLevels;

  /// Recording duration cached during card build. Interpolation runs from the ticker
  /// outside build phases and must not exceed track duration.
  Duration _duration = Duration.zero;

  /// Single source of truth for the transport button. `play(source)` re-sets the source and
  /// restarts from zero, so it may only be used when nothing is loaded yet or playback has
  /// finished; a paused player must be continued with `resume()`.
  PlayerState _playerState = PlayerState.stopped;

  /// Position being dragged on the slider. While non-null the slider follows the finger and
  /// ignores incoming position events; the actual seek happens once, on release.
  double? _dragMs;

  /// Whether audio source has been loaded into the player.
  ///
  /// Player initializes empty and remains unloaded until first playback.
  /// Seeking an uninitialized native player fails silently WITHOUT CONFIRMATION.
  /// The first seek gesture initializes the source — and playback resume must be aware
  /// of loaded state so `play(source)` does not reset the user's selected position.
  bool _sourceLoaded = false;

  /// Timeout threshold after which seeking state is reset.
  ///
  /// audioplayers defaults `AudioPlayer.seekingTimeout` to 30 s. A cursor frozen in limbo
  /// for half a minute is unhelpful — our shorter timeout resets the phantom state quickly.
  static const _seekTimeout = Duration(seconds: 2);

  /// Playback speed selected via speed pill. Transient state tied to the screen lifecycle.
  double _rate = kPlaybackRates.first;

  bool get _playing => _playerState == PlayerState.playing;

  /// Total duration used for position calculations, bar partitioning, and seek clamping.
  ///
  /// Prioritizes database value to render consistently from the first frame before
  /// player initialization, falling back to player duration if missing.
  Duration _totalOf(Recording r) =>
      r.durationMs > 0 ? Duration(milliseconds: r.durationMs) : _total;

  /// Effective displayed position: finger drag position takes precedence during scrubbing,
  /// followed by interpolated player position.
  Duration _shownPosition(Duration total) {
    final ms = _dragMs?.round() ?? _shown.value.inMilliseconds;
    return Duration(milliseconds: ms.clamp(0, total.inMilliseconds));
  }

  /// Unified seek handler: waveform taps, scrub release, 10 s skips, and fallback slider converge here.
  ///
  /// Cursor jumps immediately BEFORE dispatching seek, and position stream is muted during transit
  /// to prevent jumping back to stale positions.
  Future<void> _seekTo(Recording r, Duration target) async {
    setState(() => _dragMs = target.inMilliseconds.toDouble());
    var reached = false;
    try {
      await _loadAndSeek(r, target).timeout(_seekTimeout);
      reached = true;
    } on TimeoutException {
      // Native layer did not confirm seek within timeout.
      // Reset drag state and let position stream update naturally.
    } catch (_) {
      // Errors indicate source is unusable (missing file, decode error).
      // Mark unloaded so subsequent gestures reattempt initialization.
      _sourceLoaded = false;
    }
    if (!mounted) return;
    setState(() {
      if (reached) _rebase(target);
      _dragMs = null; // onPositionChanged resumes control
    });
    _publish();
  }

  /// Seek with lazy source loading.
  ///
  /// Seeking an unplayed track is a deliberate user action and should succeed.
  /// Loading the source does NOT initiate playback: paused state remains paused.
  Future<void> _loadAndSeek(Recording r, Duration target) async {
    if (!_sourceLoaded) {
      await _player.setSource(DeviceFileSource(r.audioPath));
      _sourceLoaded = true;
    }
    await _player.seek(target);
  }

  /// Skip 10 s backward or forward. Works during pause without altering playback state.
  Future<void> _skip(Recording r, Duration step, Duration total) =>
      _seekTo(r, skipTarget(_shownPosition(total), step, total));

  /// Cycles playback rate. Label updates immediately; native players (Android/Linux)
  /// retain rate configuration across pauses and starts.
  Future<void> _cycleRate() async {
    final next = nextPlaybackRate(_rate);
    setState(() {
      // New rate takes effect immediately. Rebase ensures prior elapsed time is not scaled retroactively.
      _rebase(_shown.value);
      _rate = next;
    });
    _publish();
    await _player.setPlaybackRate(next);
  }

  /// Publishes position for waveform and timers: interpolated during playback,
  /// direct from event otherwise. Touch drag takes precedence.
  void _publish() {
    if (_dragMs != null) return;
    _shown.value = _ticker.isActive
        ? interpolatePosition(
            base: _eventPosition,
            elapsed: _tick - _baseTick,
            rate: _rate,
            total: _duration,
          )
        : _eventPosition;
  }

  /// Rebases interpolation to [position] and resets elapsed ticker offset.
  void _rebase(Duration position) {
    _eventPosition = position;
    _baseTick = _tick;
  }

  /// Ticker runs strictly when playback state is active. Starting resets the reference baseline.
  void _syncTicker() {
    if (_playing) {
      if (!_ticker.isActive) {
        _tick = Duration.zero;
        _baseTick = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      // Pausing freezes cursor at current displayed position rather than last event position:
      // preventing visible rewinding jumps.
      _rebase(_shown.value);
      _ticker.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _tick = elapsed;
      _beat.value = elapsed;
      _publish();
    });
    _subs.add(_player.onPositionChanged.listen((event) {
      if (_dragMs != null) return; // drag gestures take precedence over position stream
      _rebase(reconcilePosition(shown: _shown.value, event: event));
      // No setState: position updates only notify [_shown].
      _publish();
    }));
    _subs.add(_player.onDurationChanged.listen((d) => setState(() => _total = d)));
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      setState(() {
        _playerState = s;
        // Sync ticker first so pause freezes cursor at current location...
        _syncTicker();
        // ...and track completion resets position to start, matching next play action.
        if (s == PlayerState.completed) {
          _rebase(Duration.zero);
          _sourceLoaded = false;
        }
      });
      _publish();
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _ticker.dispose();
    _shown.dispose();
    _beat.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _delete(Recording recording) async {
    // Read dependencies from ref BEFORE first await to avoid "used after dispose" if unmounted during dialog.
    final db = ref.read(databaseProvider);
    final selection = widget.chrome == DetailChrome.panel
        ? ref.read(selectedRecordingProvider.notifier)
        : null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.detailDeleteTitle),
          content: Text(l10n.detailDeleteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.detailCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.detailDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await _player.stop();
    if (!mounted) return;

    try {
      await db.deleteRecording(recording.id);
      // Delete directory on disk only after successful database deletion.
      try {
        final dir = File(recording.audioPath).parent;
        // Verify target path matches recording id before recursive deletion.
        if (p.basename(dir.path) == recording.id && dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
      } catch (_) {
        // File cleanup is best-effort.
      }
      if (!mounted) return;
      // Panel clears selection; standalone screen pops route.
      if (selection != null) {
        selection.clear();
      } else {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).detailDeleteError)),
      );
    }
  }

  /// Native share sheet is supported on mobile and macOS.
  /// On Linux, fallback to copying transcript to clipboard.
  bool get _hasNativeShareSheet =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  Future<void> _copyTranscript(String transcript, {required String message}) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: transcript));
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share(Recording recording) async {
    final transcript = recording.transcript;
    if (transcript == null) return;
    if (_hasNativeShareSheet) {
      await SharePlus.instance.share(ShareParams(
        text: transcript,
        subject: 'Mikro — ${formatDateTime(recording.createdAt)}',
      ));
      return;
    }
    if (!mounted) return;
    await _copyTranscript(transcript,
        message: AppLocalizations.of(context).detailCopiedTranscript);
  }

  /// Adds manual tag from "+ tag" dialog. Tag name is already normalized.
  Future<void> _addTag(RecordingWithTags item) async {
    final db = ref.read(databaseProvider);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddTagDialog(existing: item.tags),
    );
    if (name == null || !mounted) return;
    await _writeTags(() => db.addTag(item.recording.id, name));
  }

  /// Delete tag without confirmation dialog: low consequence action easily reversible via adjacent "+ tag" button.
  Future<void> _removeTag(String recordingId, String tag) =>
      _writeTags(() => ref.read(databaseProvider).removeTag(recordingId, tag));

  /// Database writes are the only point of failure for manual tag edits; handle errors and notify user.
  Future<void> _writeTags(Future<void> Function() write) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).detailTagSaveError;
    try {
      await write();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(recordingsStreamProvider);
    final l10n = AppLocalizations.of(context);
    // Error and loading states resolve BEFORE checking empty list.
    return switch (stream) {
      AsyncValue(hasError: true, :final error) =>
        _standalone(Center(child: Text(l10n.libraryDatabaseError('$error')))),
      AsyncValue(isLoading: true) =>
        _standalone(const Center(child: CircularProgressIndicator())),
      AsyncValue(:final value) => _loaded(value ?? const []),
    };
  }

  Widget _loaded(List<RecordingWithTags> all) {
    final match = all.where((r) => r.recording.id == widget.recordingId).toList();
    if (match.isEmpty) {
      return _standalone(
          Center(child: Text(AppLocalizations.of(context).detailRecordingDeleted)));
    }
    _duration = _totalOf(match.first.recording);
    return switch (widget.chrome) {
      DetailChrome.screen => _screen(match.first),
      DetailChrome.panel => _panel(match.first),
    };
  }

  /// Fallback content message wrapper. Standalone screen needs Scaffold; panel resides within library Scaffold.
  Widget _standalone(Widget child) => switch (widget.chrome) {
        DetailChrome.screen => Scaffold(body: child),
        DetailChrome.panel => child,
      };

  Widget _screen(RecordingWithTags item) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final r = item.recording;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        toolbarHeight: 64, // mockup specifies 64 px header height
        leading: IconButton(
          icon: Icon(Symbols.arrow_back_rounded, fill: 1, color: scheme.onSurface),
          tooltip: l10n.detailBackTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        // Title from recording, falling back to generic name if null.
        title: Text(
          r.title ?? l10n.detailTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        actions: [
          if (r.transcript != null)
            IconButton(
              icon: Icon(Symbols.share_rounded, fill: 1, color: scheme.onSurfaceVariant),
              tooltip: l10n.detailShareTooltip,
              onPressed: () => _share(r),
            ),
          IconButton(
            icon: Icon(Symbols.delete_rounded, fill: 1, color: scheme.onSurfaceVariant),
            tooltip: l10n.detailDeleteTooltip,
            onPressed: () => _delete(r),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _body(item),
      ),
    );
  }

  /// Desktop panel layout: technical metadata line, title, and action buttons.
  /// Header handles date and status, so player card omits duplicates.
  Widget _panel(RecordingWithTags item) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelHeader(item.recording),
            const SizedBox(height: 20),
            Expanded(child: _body(item)),
          ],
        ),
      );

  Widget _panelHeader(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatDateTime(r.createdAt)} · '
                '${formatDuration(Duration(milliseconds: r.durationMs))} · '
                '${statusLabel(r.status, l10n)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: monoStyle(size: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              // Recording title from desktop mockup, falling back to generic detail title.
              Text(
                r.title ?? l10n.detailTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  height: 34 / 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (r.transcript != null) ...[
          _PanelAction(
            icon: Symbols.share_rounded,
            tooltip: l10n.detailShareTooltip,
            onTap: () => _share(r),
          ),
          const SizedBox(width: 16),
        ],
        _PanelAction(
          icon: Symbols.delete_rounded,
          tooltip: l10n.detailDeleteTooltip,
          onTap: () => _delete(r),
        ),
      ],
    );
  }

  /// Common body content: player card, tags row, and transcript.
  Widget _body(RecordingWithTags item) {
    final gap = widget.chrome == DetailChrome.panel ? 20.0 : 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _playerCard(item.recording),
        SizedBox(height: gap),
        _tagRow(item),
        SizedBox(height: gap),
        Expanded(child: _content(item.recording)),
      ],
    );
  }

  /// Tag row from mockup: recording chips followed by trailing "+ tag" action button.
  Widget _tagRow(RecordingWithTags item) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in item.tags)
            TagChip(label: tag, onDelete: () => _removeTag(item.recording.id, tag)),
          AddTagChip(onTap: () => _addTag(item)),
        ],
      );

  /// Player card variant determined by host frame: mobile stacks transport below waveform, desktop places play button beside waveform.
  Widget _playerCard(Recording r) => switch (widget.chrome) {
        DetailChrome.screen => _mobileCard(r),
        DetailChrome.panel => _panelCard(r),
      };

  /// Mobile mockup player card: metadata, waveform, timestamps, transport row.
  Widget _mobileCard(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final total = _totalOf(r);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Date text truncates before badge on small widths.
              Expanded(
                child: Text(
                  formatDateTime(r.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(size: 13, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: r.status, showIcon: false),
            ],
          ),
          const SizedBox(height: 16),
          _followingWave(
              () => _seekSurface(r, total, height: 64)), // mockup: 64 px waveform on mobile
          const SizedBox(height: 16),
          _followingPosition(() => _times(total)),
          const SizedBox(height: 16),
          _transportRow(r, total, playButton: true),
        ],
      ),
    );
  }

  /// Desktop mockup player card: play button on the left, waveform and timestamps adjacent.
  /// Transport skip actions and speed pill sit below the pair.
  Widget _panelCard(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final total = _totalOf(r);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              _playButton(r),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _followingWave(
                        () => _seekSurface(r, total, height: 52)), // mockup: 52 px waveform in panel
                    const SizedBox(height: 10),
                    _followingPosition(() => _times(total)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _transportRow(r, total, playButton: false),
        ],
      ),
    );
  }

  /// Wraps waveform to rebuild on position changes and bar dance ticks.
  Widget _followingWave(Widget Function() build) => ListenableBuilder(
        listenable: _waveBeat,
        builder: (context, _) => build(),
      );

  /// Wraps position-dependent widgets to avoid rebuilding transcript or full card on 60 FPS animation frames.
  Widget _followingPosition(Widget Function() build) => ValueListenableBuilder<Duration>(
        valueListenable: _shown,
        builder: (context, _, _) => build(),
      );

  /// Seek surface.
  ///
  /// Recordings with stored waveforms render interactive waveform bars;
  /// legacy recordings without waveforms fall back to slider.
  Widget _seekSurface(Recording r, Duration total, {required double height}) {
    final levels = _levelsOf(r);
    if (levels == null) return _positionSlider(r, total);
    return WaveformSeekBar(
      levels: levels,
      height: height,
      // Bars animate only during playback. Static waveform renders when idle.
      beat: _playing ? _tick : null,
      position: _shownPosition(total),
      total: total,
      label: AppLocalizations.of(context).detailSeekLabel,
      onScrub: (position) =>
          setState(() => _dragMs = position.inMilliseconds.toDouble()),
      onSeek: (target) => _seekTo(r, target),
    );
  }

  /// Cached waveform levels, decoded at most once per change. See [_waveformLevels].
  List<double>? _levelsOf(Recording r) {
    if (_waveformRaw != r.waveform) {
      _waveformRaw = r.waveform;
      _waveformLevels = decodeWaveform(r.waveform);
    }
    return _waveformLevels;
  }

  /// Position slider fallback for recordings without waveforms.
  Widget _positionSlider(Recording r, Duration total) {
    final scheme = Theme.of(context).colorScheme;
    final maxMs = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outlineVariant,
        thumbColor: scheme.primary,
        thumbShape: _BarThumbShape(scheme.primary),
        overlayShape: SliderComponentShape.noOverlay,
        padding: EdgeInsets.zero,
      ),
      child: Slider(
        max: maxMs,
        value: _shownPosition(total).inMilliseconds.toDouble().clamp(0.0, maxMs),
        onChanged: (v) => setState(() => _dragMs = v),
        onChangeEnd: (v) => _seekTo(r, Duration(milliseconds: v.round())),
      ),
    );
  }

  /// Timestamps row from mockup: current position on left, duration on right.
  Widget _times(Duration total) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(formatDuration(_shownPosition(total)), style: tabularStyle(size: 12, color: color)),
        Text(formatDuration(total), style: tabularStyle(size: 12, color: color)),
      ],
    );
  }

  /// Transport row: skip buttons and speed pill aligned to right.
  Widget _transportRow(Recording r, Duration total, {required bool playButton}) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        if (playButton) ...[
          _playButton(r),
          const SizedBox(width: 8),
        ],
        _TransportAction(
          icon: Symbols.replay_10_rounded,
          tooltip: l10n.detailRewindTooltip,
          onTap: () => _skip(r, -kSkipStep, total),
        ),
        const SizedBox(width: 8),
        _TransportAction(
          icon: Symbols.forward_10_rounded,
          tooltip: l10n.detailForwardTooltip,
          onTap: () => _skip(r, kSkipStep, total),
        ),
        const Spacer(),
        _SpeedPill(rate: _rate, onTap: _cycleRate),
      ],
    );
  }

  /// Mockup transport button: 68x68 on `primary`, circle (34 dp) ⇄ squircle (18 dp) transition
  /// in 320 ms (emphasized curve `(0.2, 0, 0, 1)`), 34 dp icon.
  Widget _playButton(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(_playing ? 18 : 34);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: () => _toggle(r),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                _playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                key: ValueKey(_playing),
                fill: 1,
                size: 34,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(Recording r) async {
    switch (_playerState) {
      case PlayerState.playing:
        await _player.pause();
      case PlayerState.paused:
        // Resume from paused position.
        await _player.resume();
      case PlayerState.stopped:
      case PlayerState.completed:
      case PlayerState.disposed:
        // Resume preloaded source from seek gesture rather than restarting from zero.
        if (_sourceLoaded) {
          await _player.resume();
        } else {
          await _player.play(DeviceFileSource(r.audioPath));
          _sourceLoaded = true;
        }
    }
  }

  /// Lower screen content: error banner, loading indicator, or transcript.
  Widget _content(Recording r) {
    if (r.status == RecordingStatus.error) return _errorBanner(r);
    return _transcriptCard(r);
  }

  Widget _errorBanner(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Symbols.error_rounded, fill: 1, size: 24, color: scheme.error),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recordingErrorText(l10n, kind: r.errorKind, detail: r.errorMessage),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ErrorActionButton(
                    label: l10n.detailRetryProcessing,
                    onPressed: () => ref.read(pipelineProvider).enqueue(r.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _transcriptCard(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final transcript = r.transcript;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.detailTranscriptLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (transcript != null)
                IconButton(
                  icon: Icon(Symbols.content_copy_rounded,
                      fill: 1, size: 20, color: scheme.onSurfaceVariant),
                  tooltip: l10n.detailCopyTooltip,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _copyTranscript(transcript, message: l10n.detailCopied),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: transcript == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          statusLabel(r.status, l10n),
                          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      transcript,
                      style: TextStyle(
                        fontSize: 16,
                        height: 26 / 16,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
          ),
          if (r.providerUsed != null) ...[
            const SizedBox(height: 12),
            Text('model: ${r.providerUsed}',
                style: monoStyle(size: 13, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// Circular panel header action button: 48x48 on `surfaceContainer`, 22 px icon.
class _PanelAction extends StatelessWidget {
  const _PanelAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainer,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, fill: 1, size: 22, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Waveform seek surface: level bars, progress cursor, and scrub gestures.
///
/// Tap seeks ONCE. Dragging scrubs position visually via [onScrub] and triggers ONE seek on release via [onSeek].
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.levels,
    required this.height,
    required this.beat,
    required this.position,
    required this.total,
    required this.label,
    required this.onScrub,
    required this.onSeek,
  });

  /// Bar levels, normalized 0..1.
  final List<double> levels;

  /// Strip height: 64 in mobile card, 52 in desktop panel.
  final double height;

  /// Monotonic playback elapsed time for bar dance. `null` when paused/stopped.
  final Duration? beat;

  /// Displayed position.
  final Duration position;

  final Duration total;

  /// Accessibility label.
  final String label;

  /// Visual scrub position callback.
  final ValueChanged<Duration> onScrub;

  /// Final seek callback on gesture completion.
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  /// Last scrub position from active drag gesture.
  Duration? _dragged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      value: '${formatDuration(widget.position)} / ${formatDuration(widget.total)}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          Duration at(Offset local) =>
              positionAt(dx: local.dx, width: width, total: widget.total);
          void scrub(Offset local) {
            _dragged = at(local);
            widget.onScrub(_dragged!);
          }

          final fraction = widget.total > Duration.zero
              ? (widget.position.inMilliseconds / widget.total.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;
          final playedCount = playedBars(
            count: widget.levels.length,
            position: widget.position,
            total: widget.total,
          );

          return GestureDetector(
            // Opaque hit testing ensures taps in gaps between bars register seeks
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => widget.onSeek(at(d.localPosition)),
            onHorizontalDragStart: (d) => scrub(d.localPosition),
            onHorizontalDragUpdate: (d) => scrub(d.localPosition),
            onHorizontalDragEnd: (_) {
              widget.onSeek(_dragged ?? widget.position);
              _dragged = null;
            },
            child: WaveformBars(
              levels: widget.levels,
              height: widget.height,
              beat: widget.beat,
              progress: fraction,
              played: playedCount,
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalProgressClipper extends CustomClipper<Rect> {
  const _HorizontalProgressClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(covariant _HorizontalProgressClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Dense audio micro-waveform filling 100% width with smooth subpixel progress clipping.
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    super.key,
    required this.levels,
    required this.height,
    this.progress = 0.0,
    this.played = 0,
    this.beat,
  });

  final List<double> levels;
  final double height;
  final double progress;
  final int played;
  final Duration? beat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playedColor = scheme.primary;
    final restColor = scheme.outlineVariant.withValues(alpha: 0.75);
    final beatSeconds = beat == null
        ? null
        : beat!.inMicroseconds / Duration.microsecondsPerSecond;

    return SizedBox(
      height: height,
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _DensePillsPainter(
              levels: levels,
              color: restColor,
              beatSeconds: beatSeconds,
            ),
          ),
          ClipRect(
            clipper: _HorizontalProgressClipper(progress),
            child: CustomPaint(
              size: Size.infinite,
              painter: _DensePillsPainter(
                levels: levels,
                color: playedColor,
                beatSeconds: beatSeconds,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DensePillsPainter extends CustomPainter {
  _DensePillsPainter({
    required this.levels,
    required this.color,
    required this.beatSeconds,
  });

  final List<double> levels;
  final Color color;
  final double? beatSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) return;
    const pillWidth = 2.5;
    const minGap = 1.5;
    final count = ((size.width + minGap) / (pillWidth + minGap)).floor().clamp(20, 240);
    final step = (size.width - pillWidth) / (count - 1);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final t = count > 1 ? (i / (count - 1)) * (levels.length - 1) : 0.0;
      final i0 = t.floor().clamp(0, levels.length - 1);
      final i1 = t.ceil().clamp(0, levels.length - 1);
      final fract = t - i0;
      final base = levels[i0] + (levels[i1] - levels[i0]) * fract;
      final lvl = beatSeconds == null
          ? base
          : dancingBarLevel(level: base, elapsedSeconds: beatSeconds!, index: i % 8);
      final barH = (lvl * size.height).clamp(2.5, size.height);
      final x = i * step;
      final y = (size.height - barH) / 2;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, pillWidth, barH),
        const Radius.circular(1.25),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DensePillsPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.beatSeconds != beatSeconds ||
      oldDelegate.levels != levels;
}

/// 10 s skip button: 48x48 transparent, 24 px icon.
class _TransportAction extends StatelessWidget {
  const _TransportAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, fill: 1, size: 24, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Mockup speed pill: height 36, radius 18, background `surfaceContainerHigh`,
/// 18 px icon and 14/w500 text with localized rate formatting.
class _SpeedPill extends StatelessWidget {
  const _SpeedPill({required this.rate, required this.onTap});

  final double rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Tooltip(
      message: l10n.detailSpeedTooltip,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.speed_rounded,
                      fill: 1, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    l10n.detailSpeedLabel(formatPlaybackRate(rate, locale: locale)),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom slider thumb: 4x14 vertical bar with rounded corners.
class _BarThumbShape extends SliderComponentShape {
  const _BarThumbShape(this.color);

  final Color color;

  static const _size = Size(4, 14);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _size;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: _size.width, height: _size.height),
        const Radius.circular(2),
      ),
      Paint()..color = color,
    );
  }
}

/// Dialog for manual tag entry with duplicate prevention against existing tags.
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog({required this.existing});

  /// Tags currently assigned to the recording.
  final List<String> existing;

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => normalizeTagName(_controller.text);

  /// Duplicate check compares normalized names.
  bool get _duplicate =>
      _name.isNotEmpty && widget.existing.map(normalizeTagName).contains(_name);

  bool get _canSubmit => _name.isNotEmpty && !_duplicate;

  void _submit() {
    if (_canSubmit) Navigator.pop(context, _name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.detailAddTagTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.detailAddTagLabel,
          errorText: _duplicate ? l10n.detailAddTagDuplicate : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.detailCancel),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.detailAddTagConfirm),
        ),
      ],
    );
  }
}
