/// Where one word of the block sounds inside the block's audio.
///
/// [charStart]/[charEnd] are offsets into the BLOCK's `original_content` (same
/// frame as `char_start`/`char_end` of its fragments); [startMs]/[endMs] are
/// positions inside the block's audio file.
class AudioWord {
  final int charStart;
  final int charEnd;
  final int startMs;
  final int endMs;

  const AudioWord({
    required this.charStart,
    required this.charEnd,
    required this.startMs,
    required this.endMs,
  });

  /// `audio_words` rows are compact arrays: `[char_start, char_end, ms_start, ms_end]`.
  static List<AudioWord> listFromJson(Object? json) {
    if (json is! List) return const [];
    final words = <AudioWord>[];
    for (final row in json) {
      if (row is List && row.length >= 4) {
        words.add(AudioWord(
          charStart: (row[0] as num).toInt(),
          charEnd: (row[1] as num).toInt(),
          startMs: (row[2] as num).toInt(),
          endMs: (row[3] as num).toInt(),
        ));
      }
    }
    return words;
  }

  List<int> toJson() => [charStart, charEnd, startMs, endMs];
}

class ContentBlock {
  final int id;
  final int bookId;
  final int? pageNumber;
  final int? sequenceOrder;
  final String blockType; // 'text' | 'image' | 'code_snippet'
  final String? originalContent;
  final String? imageUrl;
  final int translated;

  /// Path inside the `block-audio` bucket (`book_1/block_5098.m4a`), or `null`
  /// while the block has no English audio yet.
  final String? audioPath;
  final int? audioMs;
  final List<AudioWord> audioWords;

  const ContentBlock({
    required this.id,
    required this.bookId,
    this.pageNumber,
    this.sequenceOrder,
    required this.blockType,
    this.originalContent,
    this.imageUrl,
    this.translated = 0,
    this.audioPath,
    this.audioMs,
    this.audioWords = const [],
  });

  bool get hasAudio => audioPath != null && audioWords.isNotEmpty;

  /// The word whose span covers [blockOffset] (an offset into
  /// `original_content`), or `null` for punctuation, citations like `[2]` that
  /// are not read aloud, or blocks without audio. Matches by OFFSET, like
  /// [BlockFragment.entryAtOffset].
  AudioWord? audioWordAt(int blockOffset) {
    for (final word in audioWords) {
      if (word.charStart <= blockOffset && blockOffset < word.charEnd) {
        return word;
      }
    }
    return null;
  }

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    return ContentBlock(
      id: json['id'] as int,
      bookId: json['book_id'] as int,
      pageNumber: json['page_number'] as int?,
      sequenceOrder: json['sequence_order'] as int?,
      blockType: json['block_type'] as String? ?? 'text',
      originalContent: json['original_content'] as String?,
      imageUrl: json['image_url'] as String?,
      translated: json['translated'] as int? ?? 0,
      audioPath: json['audio_path'] as String?,
      audioMs: json['audio_ms'] as int?,
      audioWords: AudioWord.listFromJson(json['audio_words']),
    );
  }
}
