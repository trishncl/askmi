/// Helpers for [DropdownButtonFormField] so Firestore values that don't
/// match the local items list (e.g. branch stored as a DocumentReference
/// ID like "g3UYFqZGEaV9MVaDT0aG") never crash the form at runtime.
library;

/// Removes duplicate entries while keeping first-seen order.
List<T> dedupeDropdownItems<T>(List<T> items) {
  final seen = <T>{};
  return items.where(seen.add).toList();
}

/// Returns [value] only when it appears exactly once in [items].
String? sanitizeDropdownValue(String? value, List<String> items) {
  if (value == null || value.isEmpty) return null;
  final unique = dedupeDropdownItems(items);
  return unique.where((item) => item == value).length == 1 ? value : null;
}

/// Keeps a valid Firestore/app value, otherwise falls back safely.
String resolveDropdownValue({
  required String? value,
  required List<String> items,
  required String fallback,
}) {
  final unique = dedupeDropdownItems(items);
  final sanitized = sanitizeDropdownValue(value, unique);
  if (sanitized != null) return sanitized;
  if (unique.contains(fallback)) return fallback;
  return unique.isNotEmpty ? unique.first : fallback;
}