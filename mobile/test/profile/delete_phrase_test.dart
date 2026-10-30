import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/profile/domain/delete_phrase.dart';

void main() {
  group('delete phrase matching', () {
    test('English: case, outer spaces and inner whitespace do not matter', () {
      expect(deletePhraseMatches(enStrings.deletePhrase, enStrings.deletePhrase), isTrue);
      expect(
        deletePhraseMatches('  i AM sure about   deletion and\tknow the consequences ', enStrings.deletePhrase),
        isTrue,
      );
    });

    test('English: a different or partial sentence does not match', () {
      expect(deletePhraseMatches('I am sure about deletion', enStrings.deletePhrase), isFalse);
      expect(deletePhraseMatches('I am sure about deletion and know the consequence', enStrings.deletePhrase), isFalse);
      expect(deletePhraseMatches('', enStrings.deletePhrase), isFalse);
    });

    test('Bengali: the sentence as shown matches', () {
      expect(deletePhraseMatches(bnStrings.deletePhrase, bnStrings.deletePhrase), isTrue);
      expect(deletePhraseMatches('  ${bnStrings.deletePhrase}  ', bnStrings.deletePhrase), isTrue);
    });

    test('Bengali: decomposed vowel signs (e + aa typed separately) match the composed ো', () {
      // Some keyboards type ো as ে followed by া.
      const composed = 'কো';
      const decomposed = 'কো';
      expect(normalizeDeletePhrase(decomposed), normalizeDeletePhrase(composed));
    });

    test('Bengali: য় typed as one letter or as য + nukta is the same', () {
      // "বিষয়ে" in the sentence: precomposed U+09DF vs U+09AF U+09BC.
      final precomposed = bnStrings.deletePhrase.replaceAll('য়', 'য়');
      final decomposed = bnStrings.deletePhrase.replaceAll('য়', 'য়');
      expect(precomposed == decomposed, isFalse);
      expect(deletePhraseMatches(precomposed, bnStrings.deletePhrase), isTrue);
      expect(deletePhraseMatches(decomposed, bnStrings.deletePhrase), isTrue);
    });

    test('Bengali: a different sentence does not match', () {
      expect(deletePhraseMatches('আমি নিশ্চিত', bnStrings.deletePhrase), isFalse);
    });
  });
}
