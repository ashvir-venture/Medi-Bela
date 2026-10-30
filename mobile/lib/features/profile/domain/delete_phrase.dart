/// Matching the sentence typed on the delete screen against the one shown.
///
/// Both sides are Unicode NFC-normalized, trimmed, inner whitespace
/// collapsed, and English compared case-insensitively. Dart has no built-in
/// NFC, and the sentence is only ever Bengali or English, so the canonical
/// Bengali rules are applied here (no extra package):
///  - য় ড় ঢ় (U+09DF, U+09DC, U+09DD) are composition exclusions: their NFC
///    form is the base letter + nukta (U+09BC), which keyboards also type.
///  - ো ৌ (U+09CB, U+09CC) compose from ে (U+09C7) + া (U+09BE) / ৗ (U+09D7).
/// The phrase is a guard in the app; the server checks the password.
bool deletePhraseMatches(String typed, String expected) =>
    normalizeDeletePhrase(typed) == normalizeDeletePhrase(expected);

String normalizeDeletePhrase(String value) {
  final decomposedNukta = value
      .replaceAll('য়', 'য়')
      .replaceAll('ড়', 'ড়')
      .replaceAll('ঢ়', 'ঢ়');
  final composed = decomposedNukta
      .replaceAll('ো', 'ো')
      .replaceAll('ৌ', 'ৌ');
  return composed.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
