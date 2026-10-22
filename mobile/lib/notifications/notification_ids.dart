/// `flutter_local_notifications` needs a stable `int` id per
/// notification so it can be updated/cancelled later. Dart's built-in
/// `String.hashCode` is explicitly *not* guaranteed stable across SDK
/// versions, so it can't be used here — a dose's notification would
/// silently become un-cancelable after a Dart upgrade. This is a small,
/// deterministic FNV-1a 32-bit hash instead: same input always produces
/// the same output, forever, on any platform.
int notificationIdForDose(String doseId) => notificationIdForKey(doseId);

/// Same hash for any stable string key (e.g. `health:<reminderId>`).
int notificationIdForKey(String key) {
  const fnvOffsetBasis = 0x811c9dc5;
  const fnvPrime = 0x01000193;
  var hash = fnvOffsetBasis;
  for (final codeUnit in key.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  // flutter_local_notifications expects a signed 32-bit int; mask to 31
  // bits so it's always positive.
  return hash & 0x7FFFFFFF;
}
