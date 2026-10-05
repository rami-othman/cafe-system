/// Forgiving Arabic/Latin search shared by list screens and pickers.
///
/// Mirrors `backend/app/Support/ArabicSearch.php`, so client-side and
/// server-side results are ranked the same way:
///  * letters are normalised (أ إ آ → ا، ى → ي، ة → ه، ؤ → و، ئ → ي), diacritics and
///    tatweel are removed, Arabic-Indic digits become 0-9, punctuation separates words;
///  * every typed word must match (AND) something in the searchable fields;
///  * a word matches by exact word, prefix, contained text or — for words of four
///    letters or more — a small typo (one substituted / missing / extra / swapped
///    letter, two for long words), so `الاجهزة الالكتزو` finds `الأجهزة الإلكترونية`.
library;

abstract final class ArabicSearch {
  static const Map<String, String> _letters = <String, String>{
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
    'ى': 'ي', 'ئ': 'ي', 'ة': 'ه', 'ؤ': 'و', 'ء': '',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  };
  static final RegExp _marks = RegExp('[ً-ٰٟـ]');
  static final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Lower-cases, unifies Arabic letter variants and turns punctuation into spaces.
  static String normalize(String text) {
    final StringBuffer buffer = StringBuffer();
    for (final String character in text.toLowerCase().replaceAll(_marks, '').split('')) {
      buffer.write(_letters[character] ?? character);
    }
    return buffer.toString().replaceAll(_separators, ' ').trim();
  }

  /// Normalised words with the definite article removed. With [expand], a
  /// leading conjunction "و" also yields the bare word.
  static List<String> words(String text, {bool expand = false}) {
    final String normalized = normalize(text);
    if (normalized.isEmpty) return const <String>[];
    final Set<String> result = <String>{};
    for (final String word in normalized.split(' ')) {
      result.add(_stripArticle(word));
      if (expand && word.length > 4 && word.startsWith('و')) {
        result.add(_stripArticle(word.substring(1)));
      }
    }
    return result.toList(growable: false);
  }

  /// One-off score (0 = no match). Use [ArabicSearchIndex] to search many rows.
  static int score(String query, List<String> fields) =>
      ArabicSearchIndex<List<String>>(<List<String>>[fields], (fields) => fields).scoreOf(query, 0);

  static String _stripArticle(String word) =>
      word.length > 3 && word.startsWith('ال') ? word.substring(2) : word;

  static int _wordScore(String token, String word, bool isCode) {
    if (word == token) return 100;
    if (word.startsWith(token)) return isCode ? 90 : 80;
    if (token.length >= 2 && word.contains(token)) return 40;
    final int length = token.length;
    if (length < 4 || isCode) return 0;
    final int allowed = length >= 8 ? 2 : 1;
    // Compare with the same-length beginning of the word so half-typed words still match.
    final String head = word.substring(0, word.length < length ? word.length : length);
    if (_distance(token, head, allowed) <= allowed || _distance(token, word, allowed) <= allowed) {
      return 25;
    }
    return 0;
  }

  /// Optimal-string-alignment distance (insert, delete, substitute, swap) with an early exit.
  static int _distance(String first, String second, int limit) {
    final List<int> a = first.runes.toList(growable: false);
    final List<int> b = second.runes.toList(growable: false);
    final int n = a.length;
    final int m = b.length;
    if ((n - m).abs() > limit) return limit + 1;
    List<int> previous2 = List<int>.filled(m + 1, 0);
    List<int> previous = List<int>.generate(m + 1, (int i) => i);
    for (int i = 1; i <= n; i++) {
      final List<int> current = List<int>.filled(m + 1, 0)..[0] = i;
      int rowMin = i;
      for (int j = 1; j <= m; j++) {
        final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        int value = <int>[previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost]
            .reduce((int x, int y) => x < y ? x : y);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final int swapped = previous2[j - 2] + 1;
          if (swapped < value) value = swapped;
        }
        current[j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > limit) return limit + 1;
      previous2 = previous;
      previous = current;
    }
    return previous[m];
  }
}

/// Pre-computes the normalised words of every row once, so typing in a search
/// box over thousands of rows (e.g. the 5,000-account chart) stays instant.
///
/// [fieldsOf] returns the searchable texts of an item; the FIRST one is the
/// code (matched by prefix only, never fuzzily).
final class ArabicSearchIndex<T> {
  ArabicSearchIndex(Iterable<T> items, List<String> Function(T item) fieldsOf)
    : _entries = items
          .map((T item) {
            final List<String> fields = fieldsOf(item);
            final List<(String, int)> words = <(String, int)>[];
            for (int index = 0; index < fields.length; index++) {
              for (final String word in ArabicSearch.words(fields[index], expand: true)) {
                words.add((word, index));
              }
            }
            return _Entry<T>(item, fields.map(ArabicSearch.normalize).toList(growable: false), words);
          })
          .toList(growable: false);

  final List<_Entry<T>> _entries;

  /// Matching items, best match first; equal scores keep their original order.
  List<T> search(String query, {bool Function(T item)? where}) {
    final List<String> tokens = ArabicSearch.words(query);
    if (tokens.isEmpty) {
      return _entries.map((_Entry<T> e) => e.item).where((T i) => where?.call(i) ?? true).toList();
    }
    final String phrase = ArabicSearch.normalize(query);
    final List<(int, int)> scored = <(int, int)>[];
    for (int position = 0; position < _entries.length; position++) {
      final _Entry<T> entry = _entries[position];
      if (where != null && !where(entry.item)) continue;
      final int score = _score(tokens, phrase, entry);
      if (score > 0) scored.add((score, position));
    }
    scored.sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.compareTo(b.$2));
    return scored.map(((int, int) s) => _entries[s.$2].item).toList(growable: false);
  }

  /// Score of one row (0 = no match), used by [ArabicSearch.score].
  int scoreOf(String query, int position) {
    final List<String> tokens = ArabicSearch.words(query);
    if (tokens.isEmpty) return 1;
    return _score(tokens, ArabicSearch.normalize(query), _entries[position]);
  }

  static int _score<T>(List<String> tokens, String phrase, _Entry<T> entry) {
    int total = 0;
    for (final String token in tokens) {
      int best = 0;
      for (final (String word, int field) in entry.words) {
        final int value = ArabicSearch._wordScore(token, word, field == 0);
        if (value > best) best = value;
        if (best == 100) break;
      }
      if (best == 0) return 0;
      total += best;
    }
    for (int index = 0; index < entry.fields.length; index++) {
      final String field = entry.fields[index];
      if (field.isEmpty) continue;
      if (field == phrase) {
        total += 200;
      } else if (field.startsWith(phrase)) {
        total += index == 0 ? 120 : 80;
      } else if (field.contains(phrase)) {
        total += 40;
      }
    }
    return total < 1 ? 1 : total;
  }
}

final class _Entry<T> {
  const _Entry(this.item, this.fields, this.words);
  final T item;
  final List<String> fields;
  final List<(String, int)> words;
}
