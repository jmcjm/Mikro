/// Single tag name normalization rule for the entire app: model-generated tags and manually added tags
/// must be persisted in the same format, otherwise "Meeting" and "meeting" would become two
/// separate filter chips representing the same topic.
String normalizeTagName(String raw) => raw.trim().toLowerCase();
