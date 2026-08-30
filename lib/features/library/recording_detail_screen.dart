import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/audio/waveform.dart';
import '../../core/db/database.dart';
import '../../core/models/recording_status.dart';
import '../../core/providers.dart';
import '../../core/util/format.dart';
import '../../l10n/app_localizations.dart';
import 'library_styles.dart';
import 'recording_error.dart';
import 'selected_recording.dart';

/// Rama, w ktorej stoja szczegoly nagrania. Rozstrzyga wylacznie o tym, co jest u gory
/// i dokad prowadzi kasowanie — tresc jest w obu przypadkach ta sama.
enum DetailChrome {
  /// Osobna trasa: pasek aplikacji z powrotem, akcje w jego prawym rogu.
  screen,

  /// Prawa kolumna biblioteki na szerokim ekranie: naglowek z makiety desktopowej,
  /// bez paska aplikacji i bez wlasnej trasy.
  panel,
}

/// Pelnoekranowe szczegoly nagrania. Cienka obudowa na [RecordingDetailView], zeby wywolania
/// przez Navigator.push nie musialy znac trybu ramy.
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

class _RecordingDetailViewState extends ConsumerState<RecordingDetailView> {
  final _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  final _subs = <StreamSubscription<dynamic>>[];

  /// Single source of truth for the transport button. `play(source)` re-sets the source and
  /// restarts from zero, so it may only be used when nothing is loaded yet or playback has
  /// finished; a paused player must be continued with `resume()`.
  PlayerState _playerState = PlayerState.stopped;

  /// Position being dragged on the slider. While non-null the slider follows the finger and
  /// ignores incoming position events; the actual seek happens once, on release.
  double? _dragMs;

  bool get _playing => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPositionChanged.listen((p) {
      if (_dragMs != null) return; // przeciaganie ma pierwszenstwo nad strumieniem
      setState(() => _position = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) => setState(() => _total = d)));
    _subs.add(_player.onPlayerStateChanged.listen((s) => setState(() {
          _playerState = s;
          // Po zakonczeniu nagrania suwak wraca na poczatek, zeby stan wizualny zgadzal sie
          // z tym, co zrobi kolejne wcisniecie przycisku: odtworzenie od zera.
          if (s == PlayerState.completed) _position = Duration.zero;
        })));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _delete(Recording recording) async {
    // Zaleznosci z ref pobierane PRZED pierwszym awaitem. Gdyby widget zostal zutylizowany
    // w trakcie dialogu, pozniejsze ref.read rzucaloby "used after dispose" — i to jako
    // nieobsluzony wyjatek, bo nikt tego nie lapie.
    final db = ref.read(databaseProvider);
    // Z tego samego powodu bierzemy tu kontroler wyboru: po awaitach widget moze byc juz
    // zutylizowany, a wtedy ref.read rzuca. `null` znaczy "rama ma wlasna trase do zdjecia".
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
      // Katalog kasujemy dopiero po udanym usunieciu z bazy. Gdy to zawiedzie, na dysku
      // zostaje osierocone audio — mniejsze zlo niz wpis w bazie bez pliku. Dlatego blad
      // sprzatania nie przerywa zamkniecia ekranu.
      try {
        final dir = File(recording.audioPath).parent;
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {
        // Sprzatanie plikow jest best-effort.
      }
      if (!mounted) return;
      // Panel nie jest osobna trasa, wiec nie ma czego popowac: pusty panel powstaje przez
      // wyczyszczenie wyboru, czyli powrot do stanu sprzed stukniecia w karte.
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

  /// Systemowy arkusz udostepniania istnieje tylko tam, gdzie share_plus ma natywna
  /// implementacje. Na Linuksie wtyczka sklada `mailto:` i oddaje go url_launcherowi —
  /// dyktafon otwieralby wtedy klienta poczty albo wywalal wyjatek, gdy zadnego nie ma.
  /// Dlatego desktop dostaje uczciwy zamiennik: kopie transkryptu do schowka.
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

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(recordingsStreamProvider).value ?? [];
    final match = all.where((r) => r.recording.id == widget.recordingId).toList();
    if (match.isEmpty) {
      final message =
          Center(child: Text(AppLocalizations.of(context).detailRecordingDeleted));
      return switch (widget.chrome) {
        DetailChrome.screen => Scaffold(body: message),
        DetailChrome.panel => message,
      };
    }
    return switch (widget.chrome) {
      DetailChrome.screen => _screen(match.first),
      DetailChrome.panel => _panel(match.first),
    };
  }

  Widget _screen(RecordingWithTags item) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final r = item.recording;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        toolbarHeight: 64, // makieta ma naglowek 64 px, domyslne 56 sciskaloby go za mocno
        leading: IconButton(
          icon: Icon(Symbols.arrow_back_rounded, fill: 1, color: scheme.onSurface),
          tooltip: l10n.detailBackTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.detailTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
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
        child: _body(item, showMeta: true),
      ),
    );
  }

  /// Panel z makiety desktopowej: zamiast paska aplikacji naglowek z linia techniczna,
  /// tytulem i dwoma okraglymi przyciskami akcji. Wyplata 24/28/28 jak w makiecie.
  ///
  /// Data i status ida tu do naglowka, wiec karta odtwarzacza nie powtarza ich drugi raz —
  /// makieta desktopowa ma je dokladnie w jednym miejscu.
  Widget _panel(RecordingWithTags item) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _panelHeader(item.recording),
            const SizedBox(height: 20),
            Expanded(child: _body(item, showMeta: false)),
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
              // Makieta ma w tym miejscu tytul nagrania, ktorego model danych nie zna —
              // patrz raport. Zostaje ta sama nazwa, ktora niesie pasek pelnego ekranu.
              Text(
                l10n.detailTitle,
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

  /// Tresc wspolna dla obu ram: karta odtwarzacza, tagi i transkrypt.
  Widget _body(RecordingWithTags item, {required bool showMeta}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _playerCard(item.recording, showMeta: showMeta),
          if (item.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in item.tags) TagChip(label: t)],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: _content(item.recording)),
        ],
      );

  /// Karta odtwarzania: data, status, pasek przebiegu, przycisk transportu i suwak pozycji.
  ///
  /// Przebieg rysuje sie tylko wtedy, gdy nagranie ma zapisana obwiednie. Nagrania sprzed
  /// schematu v3 maja tu NULL i karta wraca do ukladu bez slupkow — zmyslony ksztalt
  /// klamalby o tym, co slychac w pliku.
  Widget _playerCard(Recording r, {required bool showMeta}) {
    final scheme = Theme.of(context).colorScheme;
    final position = _dragMs == null ? _position : Duration(milliseconds: _dragMs!.round());
    final levels = decodeWaveform(r.waveform);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMeta) ...[
            Row(
              children: [
                // Jak na karcie w bibliotece: przy ciasnocie skraca sie data, nie odznaka.
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
          ],
          if (levels != null) ...[
            WaveformBars(levels: levels),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Material(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    switch (_playerState) {
                      case PlayerState.playing:
                        await _player.pause();
                      case PlayerState.paused:
                        // Wznowienie od miejsca pauzy — play(source) wczytalby zrodlo od nowa.
                        await _player.resume();
                      case PlayerState.stopped:
                      case PlayerState.completed:
                      case PlayerState.disposed:
                        await _player.play(DeviceFileSource(r.audioPath));
                    }
                  },
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(
                      _playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                      fill: 1,
                      size: 32,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
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
                        max: _total.inMilliseconds.toDouble().clamp(1, double.infinity),
                        value: _dragMs ??
                            _position.inMilliseconds
                                .toDouble()
                                .clamp(0, _total.inMilliseconds.toDouble()),
                        onChanged: (v) => setState(() => _dragMs = v),
                        onChangeEnd: (v) async {
                          await _player.seek(Duration(milliseconds: v.round()));
                          if (mounted) {
                            setState(() {
                              _position = Duration(milliseconds: v.round());
                              _dragMs = null; // od teraz znowu prowadzi onPositionChanged
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(position),
                            style: tabularStyle(size: 12, color: scheme.onSurfaceVariant)),
                        Text(formatDuration(Duration(milliseconds: r.durationMs)),
                            style: tabularStyle(size: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dolna czesc ekranu: banner bledu, oczekiwanie na transkrypcje albo gotowy transkrypt.
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

/// Okragly przycisk akcji z naglowka panelu: 48x48 na `surfaceContainer`, ikona 22 px.
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

/// Pasek obwiedni amplitudy z makiety: slupki w pasie 56 px, po 3 px odstepu, wysrodkowane
/// w pionie i zaokraglone na 2 px. Liczba slupkow bierze sie z danych, nie z widoku — po
/// stronie zapisu pilnuje jej [kWaveformBuckets].
class WaveformBars extends StatelessWidget {
  const WaveformBars({super.key, required this.levels});

  /// Wysokosci slupkow, 0..1.
  final List<double> levels;

  static const double _height = 56;
  static const double _gap = 3;

  /// Cichy fragment tez musi cos narysowac. Slupek zerowej wysokosci robi w pasku dziure,
  /// ktora czyta sie jak blad rysowania, a nie jak cisze.
  static const double _minBar = 2;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.85);
    final radius = BorderRadius.circular(2);
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(
              child: SizedBox(
                height: (levels[i].clamp(0.0, 1.0) * _height).clamp(_minBar, _height),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color, borderRadius: radius),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uchwyt suwaka z makiety: pionowy pasek 4x14 o zaokraglonych rogach, zamiast domyslnego
/// okraglego uchwytu Material.
class _BarThumbShape extends SliderComponentShape {
  const _BarThumbShape(this.color);

  /// Kolor wprost, a nie z `sliderTheme.thumbColor` — to pole jest nullowalne, a uchwyt nie ma
  /// sensownej wartosci awaryjnej poza rola schematu, ktora i tak podaje wolajacy.
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
