/// One word↔word alignment entry inside a fragment's `word_map`.
///
/// IMPORTANT (see FLUTTER_DB_CONTRACT §3): the offsets here are relative to the
/// FRAGMENT, not the block:
///  - [origStart]/[origEnd]  → position within `original_text` of the fragment.
///  - [transStart]/[transEnd] → position within `translated_text` of the fragment.
class WordMapEntry {
  final String original;
  final String translated;
  final int origStart;
  final int origEnd;
  final int transStart;
  final int transEnd;

  const WordMapEntry({
    required this.original,
    required this.translated,
    required this.origStart,
    required this.origEnd,
    required this.transStart,
    required this.transEnd,
  });

  factory WordMapEntry.fromJson(Map<String, dynamic> json) {
    return WordMapEntry(
      original: json['original'] as String? ?? '',
      translated: json['translated'] as String? ?? '',
      origStart: json['orig_start'] as int? ?? 0,
      origEnd: json['orig_end'] as int? ?? 0,
      transStart: json['trans_start'] as int? ?? 0,
      transEnd: json['trans_end'] as int? ?? 0,
    );
  }

  /// Same shape as the DB/Supabase row, so it round-trips through local storage.
  Map<String, dynamic> toJson() => {
        'original': original,
        'translated': translated,
        'orig_start': origStart,
        'orig_end': origEnd,
        'trans_start': transStart,
        'trans_end': transEnd,
      };
}

class BlockFragment {
  final int id;
  final int blockId;
  final int fragmentOrder;
  final String? description;
  final String originalText;
  final String? translatedText;
  final int? charStart;
  final int? charEnd;

  /// Word-level alignment. May be empty if the fragment hasn't been aligned yet
  /// (`word_map` is `null` in the DB until `align_words.py` runs).
  final List<WordMapEntry> wordMap;
  final int translated;

  const BlockFragment({
    required this.id,
    required this.blockId,
    required this.fragmentOrder,
    this.description,
    required this.originalText,
    this.translatedText,
    this.charStart,
    this.charEnd,
    this.wordMap = const [],
    this.translated = 0,
  });

  factory BlockFragment.fromJson(Map<String, dynamic> json) {
    return BlockFragment(
      id: json['id'] as int,
      blockId: json['block_id'] as int,
      fragmentOrder: json['fragment_order'] as int? ?? 0,
      description: json['description'] as String?,
      originalText: json['original_text'] as String? ?? '',
      translatedText: json['translated_text'] as String?,
      charStart: json['char_start'] as int?,
      charEnd: json['char_end'] as int?,
      wordMap: ((json['word_map'] as List?) ?? const [])
          .map((e) => WordMapEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      translated: json['translated'] as int? ?? 0,
    );
  }

  /// Finds the alignment entry that covers [offsetLocal] (an offset relative to
  /// this fragment's `original_text`). Returns `null` when the tapped word has
  /// no equivalent (punctuation, omitted article, or `word_map` not yet built).
  ///
  /// Matches by OFFSET, never by string — see FLUTTER_DB_CONTRACT §5.1.
  WordMapEntry? entryAtOffset(int offsetLocal) {
    for (final entry in wordMap) {
      if (entry.origStart <= offsetLocal && offsetLocal < entry.origEnd) {
        return entry;
      }
    }
    return null;
  }

  /// Mirror of [entryAtOffset] for the reversed direction (Spanish body):
  /// [offsetLocal] is relative to this fragment's `translated_text` and is
  /// matched against `trans_start`/`trans_end`.
  ///
  /// v1 returns the FIRST covering entry. Spanish→English alignment is
  /// many-to-one (e.g. "Anteriormente" maps from both "Previously" and "he"),
  /// so several entries may share a trans span; we highlight just the first.
  WordMapEntry? entryAtTransOffset(int offsetLocal) {
    for (final entry in wordMap) {
      if (entry.transStart <= offsetLocal && offsetLocal < entry.transEnd) {
        return entry;
      }
    }
    return null;
  }
}
