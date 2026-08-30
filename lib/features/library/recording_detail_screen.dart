import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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

  /// Czy odtwarzacz ma juz wczytane zrodlo.
  ///
  /// Odtwarzacz startuje pusty i zostaje taki az do pierwszego odtworzenia. Natywna warstwa
  /// nie ma wtedy czego przewijac: seek przechodzi bez skutku I BEZ POTWIERDZENIA, a karta
  /// pokazywalaby pozycje, ktorej nigdzie nie ma. Dlatego pierwszy gest przewijania wczytuje
  /// zrodlo — a przycisk odtwarzania musi wiedziec, ze ono juz stoi, bo `play(source)`
  /// wczytalby je drugi raz i skasowal wlasnie wybrana pozycje.
  bool _sourceLoaded = false;

  /// Po tylu sekundach karta przestaje pokazywac przewijanie jako trwajace.
  ///
  /// audioplayers czeka na potwierdzenie z natywnej warstwy przez `AudioPlayer.seekingTimeout`,
  /// czyli domyslnie 30 s. Kursor stojacy przez pol minuty w miejscu, w ktorym odtwarzacza nie
  /// ma, to nie jest czekanie, tylko fantom — wlasny, krotki limit zdejmuje go od razu.
  static const _seekTimeout = Duration(seconds: 2);

  /// Predkosc odtwarzania wybrana pigulka. Zyje tyle, co ekran: nikt nie prosil o pamietanie
  /// jej miedzy wejsciami, a ustawienie, ktore przezywa wyjscie, trzeba by gdzies pokazac.
  double _rate = kPlaybackRates.first;

  bool get _playing => _playerState == PlayerState.playing;

  /// Dlugosc, wedlug ktorej karta liczy pozycje, podzial slupkow i cel przewijania.
  ///
  /// Bierze sie z bazy, bo to ta wartosc stoi na karcie od pierwszej klatki i to ja pokazuje
  /// licznik po prawej — odtwarzacz zna swoja dopiero po wczytaniu zrodla. Nagranie bez
  /// zapisanej dlugosci (nie powinno takich byc, ale kolumna nie jest tego pewna) spada na
  /// dlugosc z odtwarzacza.
  Duration _totalOf(Recording r) =>
      r.durationMs > 0 ? Duration(milliseconds: r.durationMs) : _total;

  /// Pozycja pokazywana na karcie: w trakcie gestu prowadzi palec, poza gestem odtwarzacz.
  Duration _shownPosition(Duration total) {
    final ms = _dragMs?.round() ?? _position.inMilliseconds;
    return Duration(milliseconds: ms.clamp(0, total.inMilliseconds));
  }

  /// Jedyne wyjscie na przewijanie: stukniecie w przebieg, koniec przeciagania, skok o 10 s
  /// i suwak nagran bez obwiedni wchodza tedy. Dyscyplina jednego seeku na gest siedzi wiec
  /// w jednym miejscu, zamiast powtarzac sie w kazdym uchwycie.
  ///
  /// Kursor przeskakuje PRZED wyslaniem seeku i strumien pozycji milknie na czas jego lotu:
  /// inaczej miedzy gestem a jego skutkiem karta pokazywalaby jeszcze stara pozycje.
  Future<void> _seekTo(Recording r, Duration target) async {
    setState(() => _dragMs = target.inMilliseconds.toDouble());
    var reached = false;
    try {
      await _loadAndSeek(r, target).timeout(_seekTimeout);
      reached = true;
    } on TimeoutException {
      // Natywna warstwa nie potwierdzila przewijania w zalozonym czasie. Moze jeszcze
      // dojechac, wiec zrodla nie odznaczamy — ale kursor przestaje udawac, ze wie, gdzie
      // odtwarzacz stoi. Powie to strumien pozycji.
    } catch (_) {
      // Kazdy inny blad znaczy, ze zrodla nie da sie teraz uzyc: nie ma pliku, nie da sie go
      // zdekodowac. Odznaczamy je, zeby kolejny gest sprobowal wczytac je od nowa, zamiast
      // przewijac w pustke.
      _sourceLoaded = false;
    }
    if (!mounted) return;
    setState(() {
      if (reached) _position = target;
      _dragMs = null; // od teraz znowu prowadzi onPositionChanged
    });
  }

  /// Przewiniecie razem z leniwym wczytaniem zrodla.
  ///
  /// Gest przewijania na nagraniu, ktore jeszcze nie gralo, jest intencja uzytkownika, a nie
  /// pomylka — ma zadzialac. Wczytanie zrodla NIE zaczyna odtwarzania: pauza zostaje pauza.
  Future<void> _loadAndSeek(Recording r, Duration target) async {
    if (!_sourceLoaded) {
      await _player.setSource(DeviceFileSource(r.audioPath));
      _sourceLoaded = true;
    }
    await _player.seek(target);
  }

  /// Skok o 10 s w tyl albo w przod. Dziala takze w pauzie — seek nie rusza stanu odtwarzania,
  /// wiec przycisk przesuwa miejsce, od ktorego ruszy nastepne wcisniecie play.
  Future<void> _skip(Recording r, Duration step, Duration total) =>
      _seekTo(r, skipTarget(_shownPosition(total), step, total));

  /// Kolejna predkosc z cyklu pigulki. Etykieta zmienia sie od razu, bo obie warstwy —
  /// android i linux — trzymaja predkosc przy odtwarzaczu, a nie przy zrodle: ustawiona przy
  /// zatrzymanym odtwarzaczu wchodzi w zycie przy najblizszym starcie.
  Future<void> _cycleRate() async {
    final next = nextPlaybackRate(_rate);
    setState(() => _rate = next);
    await _player.setPlaybackRate(next);
  }

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
          // z tym, co zrobi kolejne wcisniecie przycisku: odtworzenie od zera. Zrodlo tez
          // przestaje istniec — przy domyslnym ReleaseMode.release audioplayers zwalnia je
          // razem z koncem odtwarzania.
          if (s == PlayerState.completed) {
            _position = Duration.zero;
            _sourceLoaded = false;
          }
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
        // Sciezka przychodzi z bazy, a kasowanie jest rekursywne, wiec najpierw upewniamy sie,
        // ze celujemy w katalog TEGO nagrania. Kazde audio zapisane przez aplikacje lezy
        // w <docs>/recordings/<id>/audio.m4a, wiec warunek nic nie kosztuje, a nie pozwala
        // zepsutemu albo obcemu wpisowi wyciac dowolnego katalogu.
        if (p.basename(dir.path) == recording.id && dir.existsSync()) {
          dir.deleteSync(recursive: true);
        }
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

  /// Dopisuje tag wpisany recznie w kafelku "+ tag". Nazwa wraca z okna juz znormalizowana,
  /// bo to samo sito decydowalo tam o blokadzie duplikatu.
  Future<void> _addTag(RecordingWithTags item) async {
    // Jak przy kasowaniu: zaleznosci z ref przed pierwszym awaitem, bo po zamknieciu okna
    // widget moze byc juz zutylizowany, a wtedy ref.read rzuca.
    final db = ref.read(databaseProvider);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddTagDialog(existing: item.tags),
    );
    if (name == null || !mounted) return;
    await _writeTags(() => db.addTag(item.recording.id, name));
  }

  /// Kasowanie bez okna potwierdzenia: stawka jest niska, a ruch odwracalny tym samym
  /// kafelkiem "+ tag", ktory stoi tuz obok.
  Future<void> _removeTag(String recordingId, String tag) =>
      _writeTags(() => ref.read(databaseProvider).removeTag(recordingId, tag));

  /// Zapis do bazy jest jedynym miejscem, w ktorym reczna edycja tagow moze sie wywrocic —
  /// i wywroci sie po cichu, bo nikt tego nie awaituje. Komunikat wychodzi wiec tutaj, raz
  /// dla obu sciezek.
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
    // Blad i ladowanie rozstrzygaja sie PRZED pustka. W obu tych stanach strumien nie ma
    // jeszcze wartosci, wiec nagranie wygladaloby na skasowane: awaria bazy i pierwsza klatka
    // po wejsciu na ekran meldowaly sie tym samym zdaniem, co faktycznie usuniety wpis.
    // Podzial jak na liscie w library_screen.dart.
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
    return switch (widget.chrome) {
      DetailChrome.screen => _screen(match.first),
      DetailChrome.panel => _panel(match.first),
    };
  }

  /// Komunikat zamiast tresci nagrania. Pelny ekran stoi na wlasnej trasie, wiec potrzebuje
  /// wlasnego Scaffolda; panel siedzi juz w Scaffoldzie biblioteki.
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
        toolbarHeight: 64, // makieta ma naglowek 64 px, domyslne 56 sciskaloby go za mocno
        leading: IconButton(
          icon: Icon(Symbols.arrow_back_rounded, fill: 1, color: scheme.onSurface),
          tooltip: l10n.detailBackTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        // Makieta ma tu nazwe rodzajowa, bo model danych nie znal jeszcze tytulu. Teraz zna:
        // pasek niesie tytul nagrania, a rodzajowa zostaje opadem dla nagran bez tytulu.
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
              // Tytul nagrania z makiety desktopowej. Bez tytulu zostaje ta sama nazwa
              // rodzajowa, ktora niesie pasek pelnego ekranu.
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

  /// Tresc wspolna dla obu ram: karta odtwarzacza, tagi i transkrypt. Odstep idzie za rama,
  /// bo tak ma go makieta: kolumna panelu desktopowego oddycha 20 px, kolumna pelnego
  /// ekranu 16 px.
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

  /// Rzad tagow z makiety: chipy nagrania i kafelek "+ tag" na koncu. Rzad stoi tu ZAWSZE,
  /// takze przy nagraniu bez ani jednego tagu — inaczej pierwszego tagu nie byloby jak
  /// dodac recznie.
  Widget _tagRow(RecordingWithTags item) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in item.tags)
            TagChip(label: tag, onDelete: () => _removeTag(item.recording.id, tag)),
          AddTagChip(onTap: () => _addTag(item)),
        ],
      );

  /// Karta odtwarzania. Uklad idzie za rama, bo makieta rysuje dwa rozne: telefon stawia
  /// przebieg na calej szerokosci i wiersz transportu pod spodem, panel desktopowy kladzie
  /// przycisk odtwarzania obok przebiegu.
  Widget _playerCard(Recording r) => switch (widget.chrome) {
        DetailChrome.screen => _mobileCard(r),
        DetailChrome.panel => _panelCard(r),
      };

  /// Karta z makiety telefonu: data i status, przebieg, wiersz czasow, wiersz transportu.
  /// Odstepy 16 px, jak `gap:16` w kolumnie karty.
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
          _seekSurface(r, total, height: 64), // makieta: pas 64 px w karcie telefonu
          const SizedBox(height: 16),
          _times(total),
          const SizedBox(height: 16),
          _transportRow(r, total, playButton: true),
        ],
      ),
    );
  }

  /// Karta z makiety desktopowej: przycisk odtwarzania po lewej, przebieg i czasy w kolumnie
  /// obok. Data i status stoja w naglowku panelu, wiec karta ich nie powtarza.
  ///
  /// Wiersz transportu idzie POD ta pare, a nie obok przycisku odtwarzania: przy progu ukladu
  /// szerokiego (840 px okna) na karte zostaje okolo 256 px, a play, oba skoki i pigulka nie
  /// mieszcza sie w jednej linii razem z przebiegiem. W osobnym wierszu mieszcza sie z zapasem
  /// i zachowuja rozklad z makiety telefonu: skoki po lewej, pigulka dosunieta do prawej.
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
                    _seekSurface(r, total, height: 52), // makieta: pas 52 px w panelu
                    const SizedBox(height: 10),
                    _times(total),
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

  /// Powierzchnia przewijania.
  ///
  /// Nagranie z zapisana obwiednia przewija sie po slupkach — tam, gdzie widac, co w nagraniu
  /// sie dzieje. Nagranie sprzed schematu v3 obwiedni nie ma i nie wolno jej zmyslac, wiec
  /// zostaje przy dotychczasowym suwaku: makieta nie rysuje takiego wariantu, a przewijac
  /// trzeba dac sie tak samo.
  Widget _seekSurface(Recording r, Duration total, {required double height}) {
    final levels = decodeWaveform(r.waveform);
    if (levels == null) return _positionSlider(r, total);
    return WaveformSeekBar(
      levels: levels,
      height: height,
      position: _shownPosition(total),
      total: total,
      label: AppLocalizations.of(context).detailSeekLabel,
      onScrub: (position) =>
          setState(() => _dragMs = position.inMilliseconds.toDouble()),
      onSeek: (target) => _seekTo(r, target),
    );
  }

  /// Suwak pozycji dla nagran bez obwiedni. Uchwyt i tor wprost z poprzedniej wersji karty —
  /// jedyne, co sie zmienilo, to ze przewijanie konczy sie tam, gdzie wszystkie pozostale
  /// drogi: w [_seekTo].
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

  /// Wiersz czasow z makiety: pozycja po lewej, dlugosc nagrania po prawej.
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

  /// Wiersz transportu: skoki o 10 s i pigulka predkosci dosunieta do prawej. Przycisk
  /// odtwarzania dolacza tu tylko w karcie telefonu — w panelu stoi juz obok przebiegu.
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

  /// Przycisk transportu z makiety: 64x64 na `primary`, promien 20, ikona 32.
  Widget _playButton(Recording r) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _toggle(r),
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
    );
  }

  Future<void> _toggle(Recording r) async {
    switch (_playerState) {
      case PlayerState.playing:
        await _player.pause();
      case PlayerState.paused:
        // Wznowienie od miejsca pauzy — play(source) wczytalby zrodlo od nowa.
        await _player.resume();
      case PlayerState.stopped:
      case PlayerState.completed:
      case PlayerState.disposed:
        // Zrodlo wczytane wczesniej gestem przewijania trzeba WZNOWIC, a nie wczytac drugi
        // raz: `play(source)` zaczalby od zera i skasowal pozycje, ktora uzytkownik wlasnie
        // wybral, jeszcze zanim uslyszal pierwszy dzwiek.
        if (_sourceLoaded) {
          await _player.resume();
        } else {
          await _player.play(DeviceFileSource(r.audioPath));
          _sourceLoaded = true;
        }
    }
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

/// Przebieg jako powierzchnia przewijania: slupki, kursor pozycji i gesty.
///
/// Stukniecie przewija RAZ. Przeciaganie prowadzi kursor za palcem przez [onScrub] — to sam
/// stan wizualny, bez ruszania odtwarzacza — i konczy sie JEDNYM przewinieciem przez [onSeek].
/// Ta sama dyscyplina siedziala wczesniej w `onChangeEnd` suwaka: seek w kazdej klatce gestu
/// zasypywalby odtwarzacz zadaniami, ktorych i tak nikt nie uslyszy.
class WaveformSeekBar extends StatefulWidget {
  const WaveformSeekBar({
    super.key,
    required this.levels,
    required this.height,
    required this.position,
    required this.total,
    required this.label,
    required this.onScrub,
    required this.onSeek,
  });

  /// Wysokosci slupkow, 0..1.
  final List<double> levels;

  /// Wysokosc pasa: 64 w karcie telefonu, 52 w panelu desktopowym.
  final double height;

  /// Pozycja, na ktorej stoi kursor. W trakcie gestu jest to wartosc z ostatniego [onScrub],
  /// bo rodzic oddaje ja z powrotem — i dlatego koniec przeciagania ma czym przewinac.
  final Duration position;

  final Duration total;

  /// Etykieta dostepnosci. Suwak niosl ja sam z siebie, powierzchnia gestow juz nie.
  final String label;

  /// Pozycja w trakcie gestu: stan wizualny, bez przewijania.
  final ValueChanged<Duration> onScrub;

  /// Jedno przewiniecie: stukniecie albo koniec przeciagania.
  final ValueChanged<Duration> onSeek;

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> {
  /// Ostatnia pozycja z trwajacego przeciagania. Koniec gestu nie niesie wspolrzednych, a
  /// czytanie ich z `widget.position` bylo by spoznione o klatke: rodzic dostaje je przez
  /// setState, wiec do widgetu wracaja dopiero przy nastepnym budowaniu — a to potrafi nie
  /// zdazyc przed puszczeniem palca. Pole nie maluje niczego, wiec nie wola setState.
  Duration? _dragged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.label,
      value: '${formatDuration(widget.position)} / ${formatDuration(widget.total)}',
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            Duration at(Offset local) =>
                positionAt(dx: local.dx, width: width, total: widget.total);
            void scrub(Offset local) {
              _dragged = at(local);
              widget.onScrub(_dragged!);
            }

            return GestureDetector(
              // Slupki nie wypelniaja calego pasa, a przerwy miedzy nimi maja przewijac tak
              // samo jak one.
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => widget.onSeek(at(d.localPosition)),
              onHorizontalDragStart: (d) => scrub(d.localPosition),
              onHorizontalDragUpdate: (d) => scrub(d.localPosition),
              onHorizontalDragEnd: (_) {
                widget.onSeek(_dragged ?? widget.position);
                _dragged = null;
              },
              child: Stack(
                // Kursor wystaje 4 px nad slupki i pod nie; przyciety wygladalby na urwany.
                clipBehavior: Clip.none,
                children: [
                  WaveformBars(
                    levels: widget.levels,
                    height: widget.height,
                    played: playedBars(
                      count: widget.levels.length,
                      position: widget.position,
                      total: widget.total,
                    ),
                  ),
                  _cursor(context, width),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Kursor pozycji z makiety: pasek 4 px w kolorze `primary`, z halo 3 px w kolorze karty
  /// (`box-shadow:0 0 0 3px var(--sc2)`), wystajacy 4 px poza pas slupkow.
  Widget _cursor(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    const barWidth = 4.0;
    final fraction = widget.total > Duration.zero
        ? (widget.position.inMilliseconds / widget.total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    // Kursor stoi SRODKIEM na pozycji, wiec na obu koncach nagrania trzeba go wciagnac
    // z powrotem w pas — inaczej polowa wisialaby poza karta.
    final left = (width * fraction - barWidth / 2).clamp(0.0, (width - barWidth).clamp(0.0, width));
    return Positioned(
      left: left,
      top: -4,
      bottom: -4,
      width: barWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: scheme.surfaceContainer, spreadRadius: 3)],
        ),
      ),
    );
  }
}

/// Pasek obwiedni amplitudy z makiety: slupki po 3 px odstepu, wysrodkowane w pionie
/// i zaokraglone na 2 px. Liczba slupkow bierze sie z danych, nie z widoku — po stronie
/// zapisu pilnuje jej [kWaveformBuckets].
///
/// Slupek zagrany dostaje pelny `primary`, niezagrany przygaszony `outlineVariant` — podzial
/// z makiety, ktory robi z przebiegu takze wskaznik postepu.
class WaveformBars extends StatelessWidget {
  const WaveformBars({
    super.key,
    required this.levels,
    required this.height,
    required this.played,
  });

  /// Wysokosci slupkow, 0..1.
  final List<double> levels;

  /// Wysokosc pasa.
  final double height;

  /// Ile pierwszych slupkow jest juz zagranych.
  final int played;

  static const double _gap = 3;

  /// Cichy fragment tez musi cos narysowac. Slupek zerowej wysokosci robi w pasku dziure,
  /// ktora czyta sie jak blad rysowania, a nie jak cisze.
  static const double _minBar = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(2);
    final playedColor = scheme.primary;
    final restColor = scheme.outlineVariant.withValues(alpha: 0.75);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(
              child: SizedBox(
                height: (levels[i].clamp(0.0, 1.0) * height).clamp(_minBar, height),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i < played ? playedColor : restColor,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Przycisk skoku o 10 s: 48x48 bez tla, ikona 24 — jak w wierszu transportu makiety.
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

/// Pigulka predkosci z makiety: wysokosc 36, promien 18, tlo `surfaceContainerHigh`,
/// ikona 18 i liczba 14/w500 ze znakiem mnozenia.
///
/// Sama liczba idzie przez [formatPlaybackRate], bo separator dziesietny zalezy od jezyka
/// ("1,0" po polsku, "1.0" po angielsku), a znak mnozenia doklada ARB.
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

/// Minimalne okno recznego dodania tagu. Makieta nie rysuje formularza — kafelek "+ tag" jest
/// jedynym sladem tej sciezki — wiec okno trzyma sie tego, co ekran juz ma: MD3 AlertDialog
/// z jednym polem i para akcji, jak przy kasowaniu nagrania.
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog({required this.existing});

  /// Tagi juz przypiete do nagrania. Sluza wylacznie do blokady duplikatu.
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

  /// Porownanie idzie po znormalizowanych nazwach, wiec "Spotkanie" nie przejdzie obok
  /// istniejacego "spotkanie" — do bazy i tak trafilaby ta sama nazwa.
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
