class ContentBlock {
  final int id;
  final int bookId;
  final int? pageNumber;
  final int? sequenceOrder;
  final String blockType; // 'text' | 'image' | 'code_snippet'
  final String? originalContent;
  final String? imageUrl;
  final int translated;

  const ContentBlock({
    required this.id,
    required this.bookId,
    this.pageNumber,
    this.sequenceOrder,
    required this.blockType,
    this.originalContent,
    this.imageUrl,
    this.translated = 0,
  });

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
    );
  }
}
