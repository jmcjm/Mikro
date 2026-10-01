import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/provider_config.dart';
import '../providers.dart';

/// A style the user wrote: a name shown in the picker and instructions sent to the model.
class CustomNoteStyle {
  const CustomNoteStyle({required this.id, required this.name, required this.instructions});

  /// Stable id, so the last-used choice survives renaming the style.
  final String id;

  /// Empty only for the style migrated from the single "custom" text of older versions —
  /// the UI shows a generic label for it.
  final String name;
  final String instructions;

  static CustomNoteStyle? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final instructions = json['instructions'];
    if (id is! String || name is! String || instructions is! String) return null;
    return CustomNoteStyle(id: id, name: name, instructions: instructions);
  }

  Map<String, String> toJson() => {'id': id, 'name': name, 'instructions': instructions};
}

/// Style picked for one generation: a preset or one of the user's own styles.
class NoteStyleChoice {
  const NoteStyleChoice.preset(this.style)
      : assert(style != NoteStyle.custom),
        custom = null;

  const NoteStyleChoice.custom(CustomNoteStyle this.custom) : style = NoteStyle.custom;

  static const detailed = NoteStyleChoice.preset(NoteStyle.detailed);

  /// [NoteStyle.custom] exactly when [custom] is set.
  final NoteStyle style;
  final CustomNoteStyle? custom;

  /// Text for [NotesApi.generate]'s `customStyle`; empty for presets.
  String get instructions => custom?.instructions ?? '';

  @override
  bool operator ==(Object other) =>
      other is NoteStyleChoice && other.style == style && other.custom?.id == custom?.id;

  @override
  int get hashCode => Object.hash(style, custom?.id);
}

/// Preference keys — the on-disk format, pinned by tests.
///
/// Older versions had ONE custom text (`notes_style_custom`) and picked the style in settings
/// (`notes_style`). The text is read as a nameless custom style until the list is first saved,
/// and `notes_style` lives on as the style used last, which the picker preselects.
const noteStyleKey = 'notes_style';
const noteStyleCustomIdKey = 'notes_style_custom_id';
const legacyNoteStyleCustomKey = 'notes_style_custom';
const customNoteStylesKey = 'notes_custom_styles';

/// Id of the style migrated from `notes_style_custom`.
const legacyCustomStyleId = 'legacy';

/// The user's own note styles, persisted. Shared by the settings screen (which edits them)
/// and the style picker, so every screen sees one list and no stale copy writes over another.
class CustomNoteStylesController extends Notifier<List<CustomNoteStyle>> {
  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  List<CustomNoteStyle> build() {
    // Untyped reads, as in the theme controllers: a value of another type must fall back,
    // not throw in the middle of a build.
    final stored = _prefs.get(customNoteStylesKey);
    if (stored is String) {
      try {
        final decoded = jsonDecode(stored);
        if (decoded is List) {
          return [
            for (final item in decoded) ?CustomNoteStyle.fromJson(item),
          ];
        }
      } on FormatException {
        // Corrupt value: start over rather than lose the whole screen.
      }
      return const [];
    }
    final legacy = _prefs.get(legacyNoteStyleCustomKey);
    if (legacy is String && legacy.trim().isNotEmpty) {
      return [CustomNoteStyle(id: legacyCustomStyleId, name: '', instructions: legacy.trim())];
    }
    return const [];
  }

  Future<void> add({required String name, required String instructions}) => _write([
        ...state,
        CustomNoteStyle(id: const Uuid().v4(), name: name, instructions: instructions),
      ]);

  Future<void> edit(CustomNoteStyle style) =>
      _write([for (final s in state) s.id == style.id ? style : s]);

  Future<void> remove(String id) => _write([for (final s in state) if (s.id != id) s]);

  Future<void> _write(List<CustomNoteStyle> styles) async {
    state = styles;
    await _prefs.setString(
        customNoteStylesKey, jsonEncode([for (final s in styles) s.toJson()]));
  }
}

final customNoteStylesProvider =
    NotifierProvider<CustomNoteStylesController, List<CustomNoteStyle>>(
        CustomNoteStylesController.new);

/// Style the picker preselects: the one used last, as long as it still exists.
NoteStyleChoice lastNoteStyle(SharedPreferences prefs, List<CustomNoteStyle> custom) {
  final name = prefs.get(noteStyleKey);
  if (name == NoteStyle.custom.name) {
    final id = prefs.get(noteStyleCustomIdKey);
    // No id: the choice was saved by a version with a single custom text.
    final wanted = id is String ? id : legacyCustomStyleId;
    final style = custom.where((s) => s.id == wanted).firstOrNull;
    return style == null ? NoteStyleChoice.detailed : NoteStyleChoice.custom(style);
  }
  final preset = NoteStyle.values.asNameMap()[name];
  return preset == null || preset == NoteStyle.custom
      ? NoteStyleChoice.detailed
      : NoteStyleChoice.preset(preset);
}

Future<void> saveLastNoteStyle(SharedPreferences prefs, NoteStyleChoice choice) async {
  await prefs.setString(noteStyleKey, choice.style.name);
  final custom = choice.custom;
  if (custom != null) {
    await prefs.setString(noteStyleCustomIdKey, custom.id);
  } else {
    await prefs.remove(noteStyleCustomIdKey);
  }
}
