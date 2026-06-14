class Book {
  final int id;
  final String title;
  final String? author;
  final int? totalPages;
  final String? language;
  final String? coverUrl;
  final DateTime? createdAt;

  const Book({
    required this.id,
    required this.title,
    this.author,
    this.totalPages,
    this.language,
    this.coverUrl,
    this.createdAt,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      totalPages: json['total_pages'] as int?,
      language: json['language'] as String?,
      coverUrl: json['cover_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
