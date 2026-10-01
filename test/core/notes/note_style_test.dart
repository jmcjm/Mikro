import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mikro/core/models/provider_config.dart';
import 'package:mikro/core/notes/note_style.dart';
import 'package:mikro/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  Future<ProviderContainer> container(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    return c;
  }

  test('GUARD: preference keys', () {
    expect(noteStyleKey, 'notes_style');
    expect(noteStyleCustomIdKey, 'notes_style_custom_id');
    expect(legacyNoteStyleCustomKey, 'notes_style_custom');
    expect(customNoteStylesKey, 'notes_custom_styles');
  });

  test('no custom styles on a fresh install', () async {
    final c = await container({});
    expect(c.read(customNoteStylesProvider), isEmpty);
    expect(lastNoteStyle(prefs, const []), NoteStyleChoice.detailed);
  });

  test('add, edit and remove persist and survive a restart', () async {
    final c = await container({});
    final styles = c.read(customNoteStylesProvider.notifier);
    await styles.add(name: 'Nauka', instructions: 'Definicje.');
    await styles.add(name: 'Haiku', instructions: 'Tylko haiku.');
    final first = c.read(customNoteStylesProvider).first;
    await styles.edit(CustomNoteStyle(id: first.id, name: 'Do nauki', instructions: 'Pytania.'));
    await styles.remove(c.read(customNoteStylesProvider).last.id);

    final restarted = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(restarted.dispose);
    final loaded = restarted.read(customNoteStylesProvider);
    expect(loaded, hasLength(1));
    expect(loaded.single.id, first.id, reason: 'editing keeps the id');
    expect(loaded.single.name, 'Do nauki');
    expect(loaded.single.instructions, 'Pytania.');
  });

  test('the single custom text of older versions becomes a nameless style', () async {
    final c = await container({'notes_style': 'custom', 'notes_style_custom': ' Krótko. '});
    final styles = c.read(customNoteStylesProvider);
    expect(styles.single.name, '');
    expect(styles.single.instructions, 'Krótko.');
    expect(lastNoteStyle(prefs, styles), NoteStyleChoice.custom(styles.single),
        reason: 'it was the style in use, so it stays preselected');
  });

  test('once the list is saved, the old text does not come back', () async {
    final c = await container({'notes_style_custom': 'Krótko.'});
    await c.read(customNoteStylesProvider.notifier).remove(legacyCustomStyleId);

    final restarted = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(restarted.dispose);
    expect(restarted.read(customNoteStylesProvider), isEmpty);
  });

  test('a corrupt or foreign stored list reads as empty instead of throwing', () async {
    expect((await container({'notes_custom_styles': '{nie json'})).read(customNoteStylesProvider),
        isEmpty);
    expect((await container({'notes_custom_styles': 7})).read(customNoteStylesProvider), isEmpty);
    final mixed = await container(
        {'notes_custom_styles': '[{"id":"a","name":"A","instructions":"x"}, 3, {"id":1}]'});
    expect(mixed.read(customNoteStylesProvider).single.id, 'a');
  });

  test('last style round-trips; a deleted or unknown one falls back to detailed', () async {
    await container({});
    const haiku = CustomNoteStyle(id: 'h', name: 'Haiku', instructions: 'Tylko haiku.');

    await saveLastNoteStyle(prefs, const NoteStyleChoice.custom(haiku));
    expect(lastNoteStyle(prefs, const [haiku]), const NoteStyleChoice.custom(haiku));
    expect(lastNoteStyle(prefs, const []), NoteStyleChoice.detailed, reason: 'deleted since');

    await saveLastNoteStyle(prefs, const NoteStyleChoice.preset(NoteStyle.meeting));
    expect(lastNoteStyle(prefs, const [haiku]), const NoteStyleChoice.preset(NoteStyle.meeting));
    expect(prefs.getString(noteStyleCustomIdKey), isNull);

    await prefs.setString(noteStyleKey, 'z-przyszlej-wersji');
    expect(lastNoteStyle(prefs, const []), NoteStyleChoice.detailed);
  });
}
