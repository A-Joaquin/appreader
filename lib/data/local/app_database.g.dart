// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalBooksTable extends LocalBooks
    with TableInfo<$LocalBooksTable, LocalBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalPagesMeta = const VerificationMeta(
    'totalPages',
  );
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
    'total_pages',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    totalPages,
    language,
    coverUrl,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('total_pages')) {
      context.handle(
        _totalPagesMeta,
        totalPages.isAcceptableOrUnknown(data['total_pages']!, _totalPagesMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_downloadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBook(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      totalPages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      )!,
    );
  }

  @override
  $LocalBooksTable createAlias(String alias) {
    return $LocalBooksTable(attachedDatabase, alias);
  }
}

class LocalBook extends DataClass implements Insertable<LocalBook> {
  final int id;
  final String title;
  final String? author;
  final int? totalPages;
  final String? language;
  final String? coverUrl;
  final DateTime downloadedAt;
  const LocalBook({
    required this.id,
    required this.title,
    this.author,
    this.totalPages,
    this.language,
    this.coverUrl,
    required this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || totalPages != null) {
      map['total_pages'] = Variable<int>(totalPages);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    return map;
  }

  LocalBooksCompanion toCompanion(bool nullToAbsent) {
    return LocalBooksCompanion(
      id: Value(id),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      totalPages: totalPages == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPages),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      downloadedAt: Value(downloadedAt),
    );
  }

  factory LocalBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBook(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      totalPages: serializer.fromJson<int?>(json['totalPages']),
      language: serializer.fromJson<String?>(json['language']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      downloadedAt: serializer.fromJson<DateTime>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'totalPages': serializer.toJson<int?>(totalPages),
      'language': serializer.toJson<String?>(language),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'downloadedAt': serializer.toJson<DateTime>(downloadedAt),
    };
  }

  LocalBook copyWith({
    int? id,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<int?> totalPages = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    DateTime? downloadedAt,
  }) => LocalBook(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    totalPages: totalPages.present ? totalPages.value : this.totalPages,
    language: language.present ? language.value : this.language,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    downloadedAt: downloadedAt ?? this.downloadedAt,
  );
  LocalBook copyWithCompanion(LocalBooksCompanion data) {
    return LocalBook(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      totalPages: data.totalPages.present
          ? data.totalPages.value
          : this.totalPages,
      language: data.language.present ? data.language.value : this.language,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBook(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('totalPages: $totalPages, ')
          ..write('language: $language, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    totalPages,
    language,
    coverUrl,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBook &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.totalPages == this.totalPages &&
          other.language == this.language &&
          other.coverUrl == this.coverUrl &&
          other.downloadedAt == this.downloadedAt);
}

class LocalBooksCompanion extends UpdateCompanion<LocalBook> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> author;
  final Value<int?> totalPages;
  final Value<String?> language;
  final Value<String?> coverUrl;
  final Value<DateTime> downloadedAt;
  const LocalBooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.language = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  });
  LocalBooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.author = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.language = const Value.absent(),
    this.coverUrl = const Value.absent(),
    required DateTime downloadedAt,
  }) : title = Value(title),
       downloadedAt = Value(downloadedAt);
  static Insertable<LocalBook> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<int>? totalPages,
    Expression<String>? language,
    Expression<String>? coverUrl,
    Expression<DateTime>? downloadedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (totalPages != null) 'total_pages': totalPages,
      if (language != null) 'language': language,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
    });
  }

  LocalBooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? author,
    Value<int?>? totalPages,
    Value<String?>? language,
    Value<String?>? coverUrl,
    Value<DateTime>? downloadedAt,
  }) {
    return LocalBooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      totalPages: totalPages ?? this.totalPages,
      language: language ?? this.language,
      coverUrl: coverUrl ?? this.coverUrl,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('totalPages: $totalPages, ')
          ..write('language: $language, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalBlocksTable extends LocalBlocks
    with TableInfo<$LocalBlocksTable, LocalBlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sequenceOrderMeta = const VerificationMeta(
    'sequenceOrder',
  );
  @override
  late final GeneratedColumn<int> sequenceOrder = GeneratedColumn<int>(
    'sequence_order',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockTypeMeta = const VerificationMeta(
    'blockType',
  );
  @override
  late final GeneratedColumn<String> blockType = GeneratedColumn<String>(
    'block_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalContentMeta = const VerificationMeta(
    'originalContent',
  );
  @override
  late final GeneratedColumn<String> originalContent = GeneratedColumn<String>(
    'original_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    pageNumber,
    sequenceOrder,
    blockType,
    originalContent,
    imageUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalBlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('sequence_order')) {
      context.handle(
        _sequenceOrderMeta,
        sequenceOrder.isAcceptableOrUnknown(
          data['sequence_order']!,
          _sequenceOrderMeta,
        ),
      );
    }
    if (data.containsKey('block_type')) {
      context.handle(
        _blockTypeMeta,
        blockType.isAcceptableOrUnknown(data['block_type']!, _blockTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_blockTypeMeta);
    }
    if (data.containsKey('original_content')) {
      context.handle(
        _originalContentMeta,
        originalContent.isAcceptableOrUnknown(
          data['original_content']!,
          _originalContentMeta,
        ),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalBlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalBlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      sequenceOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_order'],
      ),
      blockType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_type'],
      )!,
      originalContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_content'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
    );
  }

  @override
  $LocalBlocksTable createAlias(String alias) {
    return $LocalBlocksTable(attachedDatabase, alias);
  }
}

class LocalBlock extends DataClass implements Insertable<LocalBlock> {
  final int id;
  final int bookId;
  final int? pageNumber;
  final int? sequenceOrder;
  final String blockType;
  final String? originalContent;
  final String? imageUrl;
  const LocalBlock({
    required this.id,
    required this.bookId,
    this.pageNumber,
    this.sequenceOrder,
    required this.blockType,
    this.originalContent,
    this.imageUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    if (!nullToAbsent || sequenceOrder != null) {
      map['sequence_order'] = Variable<int>(sequenceOrder);
    }
    map['block_type'] = Variable<String>(blockType);
    if (!nullToAbsent || originalContent != null) {
      map['original_content'] = Variable<String>(originalContent);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    return map;
  }

  LocalBlocksCompanion toCompanion(bool nullToAbsent) {
    return LocalBlocksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      sequenceOrder: sequenceOrder == null && nullToAbsent
          ? const Value.absent()
          : Value(sequenceOrder),
      blockType: Value(blockType),
      originalContent: originalContent == null && nullToAbsent
          ? const Value.absent()
          : Value(originalContent),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
    );
  }

  factory LocalBlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalBlock(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      sequenceOrder: serializer.fromJson<int?>(json['sequenceOrder']),
      blockType: serializer.fromJson<String>(json['blockType']),
      originalContent: serializer.fromJson<String?>(json['originalContent']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'sequenceOrder': serializer.toJson<int?>(sequenceOrder),
      'blockType': serializer.toJson<String>(blockType),
      'originalContent': serializer.toJson<String?>(originalContent),
      'imageUrl': serializer.toJson<String?>(imageUrl),
    };
  }

  LocalBlock copyWith({
    int? id,
    int? bookId,
    Value<int?> pageNumber = const Value.absent(),
    Value<int?> sequenceOrder = const Value.absent(),
    String? blockType,
    Value<String?> originalContent = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
  }) => LocalBlock(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    sequenceOrder: sequenceOrder.present
        ? sequenceOrder.value
        : this.sequenceOrder,
    blockType: blockType ?? this.blockType,
    originalContent: originalContent.present
        ? originalContent.value
        : this.originalContent,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
  );
  LocalBlock copyWithCompanion(LocalBlocksCompanion data) {
    return LocalBlock(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      sequenceOrder: data.sequenceOrder.present
          ? data.sequenceOrder.value
          : this.sequenceOrder,
      blockType: data.blockType.present ? data.blockType.value : this.blockType,
      originalContent: data.originalContent.present
          ? data.originalContent.value
          : this.originalContent,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlock(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('sequenceOrder: $sequenceOrder, ')
          ..write('blockType: $blockType, ')
          ..write('originalContent: $originalContent, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    pageNumber,
    sequenceOrder,
    blockType,
    originalContent,
    imageUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalBlock &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.pageNumber == this.pageNumber &&
          other.sequenceOrder == this.sequenceOrder &&
          other.blockType == this.blockType &&
          other.originalContent == this.originalContent &&
          other.imageUrl == this.imageUrl);
}

class LocalBlocksCompanion extends UpdateCompanion<LocalBlock> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<int?> pageNumber;
  final Value<int?> sequenceOrder;
  final Value<String> blockType;
  final Value<String?> originalContent;
  final Value<String?> imageUrl;
  const LocalBlocksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.sequenceOrder = const Value.absent(),
    this.blockType = const Value.absent(),
    this.originalContent = const Value.absent(),
    this.imageUrl = const Value.absent(),
  });
  LocalBlocksCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    this.pageNumber = const Value.absent(),
    this.sequenceOrder = const Value.absent(),
    required String blockType,
    this.originalContent = const Value.absent(),
    this.imageUrl = const Value.absent(),
  }) : bookId = Value(bookId),
       blockType = Value(blockType);
  static Insertable<LocalBlock> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<int>? pageNumber,
    Expression<int>? sequenceOrder,
    Expression<String>? blockType,
    Expression<String>? originalContent,
    Expression<String>? imageUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (pageNumber != null) 'page_number': pageNumber,
      if (sequenceOrder != null) 'sequence_order': sequenceOrder,
      if (blockType != null) 'block_type': blockType,
      if (originalContent != null) 'original_content': originalContent,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  LocalBlocksCompanion copyWith({
    Value<int>? id,
    Value<int>? bookId,
    Value<int?>? pageNumber,
    Value<int?>? sequenceOrder,
    Value<String>? blockType,
    Value<String?>? originalContent,
    Value<String?>? imageUrl,
  }) {
    return LocalBlocksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      blockType: blockType ?? this.blockType,
      originalContent: originalContent ?? this.originalContent,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (sequenceOrder.present) {
      map['sequence_order'] = Variable<int>(sequenceOrder.value);
    }
    if (blockType.present) {
      map['block_type'] = Variable<String>(blockType.value);
    }
    if (originalContent.present) {
      map['original_content'] = Variable<String>(originalContent.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalBlocksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('sequenceOrder: $sequenceOrder, ')
          ..write('blockType: $blockType, ')
          ..write('originalContent: $originalContent, ')
          ..write('imageUrl: $imageUrl')
          ..write(')'))
        .toString();
  }
}

class $LocalFragmentsTable extends LocalFragments
    with TableInfo<$LocalFragmentsTable, LocalFragment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFragmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<int> blockId = GeneratedColumn<int>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fragmentOrderMeta = const VerificationMeta(
    'fragmentOrder',
  );
  @override
  late final GeneratedColumn<int> fragmentOrder = GeneratedColumn<int>(
    'fragment_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTextMeta = const VerificationMeta(
    'originalText',
  );
  @override
  late final GeneratedColumn<String> originalText = GeneratedColumn<String>(
    'original_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translatedTextMeta = const VerificationMeta(
    'translatedText',
  );
  @override
  late final GeneratedColumn<String> translatedText = GeneratedColumn<String>(
    'translated_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _charStartMeta = const VerificationMeta(
    'charStart',
  );
  @override
  late final GeneratedColumn<int> charStart = GeneratedColumn<int>(
    'char_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _charEndMeta = const VerificationMeta(
    'charEnd',
  );
  @override
  late final GeneratedColumn<int> charEnd = GeneratedColumn<int>(
    'char_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordMapJsonMeta = const VerificationMeta(
    'wordMapJson',
  );
  @override
  late final GeneratedColumn<String> wordMapJson = GeneratedColumn<String>(
    'word_map_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    blockId,
    fragmentOrder,
    originalText,
    translatedText,
    charStart,
    charEnd,
    wordMapJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_fragments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalFragment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('fragment_order')) {
      context.handle(
        _fragmentOrderMeta,
        fragmentOrder.isAcceptableOrUnknown(
          data['fragment_order']!,
          _fragmentOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fragmentOrderMeta);
    }
    if (data.containsKey('original_text')) {
      context.handle(
        _originalTextMeta,
        originalText.isAcceptableOrUnknown(
          data['original_text']!,
          _originalTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalTextMeta);
    }
    if (data.containsKey('translated_text')) {
      context.handle(
        _translatedTextMeta,
        translatedText.isAcceptableOrUnknown(
          data['translated_text']!,
          _translatedTextMeta,
        ),
      );
    }
    if (data.containsKey('char_start')) {
      context.handle(
        _charStartMeta,
        charStart.isAcceptableOrUnknown(data['char_start']!, _charStartMeta),
      );
    }
    if (data.containsKey('char_end')) {
      context.handle(
        _charEndMeta,
        charEnd.isAcceptableOrUnknown(data['char_end']!, _charEndMeta),
      );
    }
    if (data.containsKey('word_map_json')) {
      context.handle(
        _wordMapJsonMeta,
        wordMapJson.isAcceptableOrUnknown(
          data['word_map_json']!,
          _wordMapJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalFragment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFragment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}block_id'],
      )!,
      fragmentOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fragment_order'],
      )!,
      originalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_text'],
      )!,
      translatedText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_text'],
      ),
      charStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_start'],
      ),
      charEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_end'],
      ),
      wordMapJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_map_json'],
      ),
    );
  }

  @override
  $LocalFragmentsTable createAlias(String alias) {
    return $LocalFragmentsTable(attachedDatabase, alias);
  }
}

class LocalFragment extends DataClass implements Insertable<LocalFragment> {
  final int id;
  final int blockId;
  final int fragmentOrder;
  final String originalText;
  final String? translatedText;
  final int? charStart;
  final int? charEnd;
  final String? wordMapJson;
  const LocalFragment({
    required this.id,
    required this.blockId,
    required this.fragmentOrder,
    required this.originalText,
    this.translatedText,
    this.charStart,
    this.charEnd,
    this.wordMapJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['block_id'] = Variable<int>(blockId);
    map['fragment_order'] = Variable<int>(fragmentOrder);
    map['original_text'] = Variable<String>(originalText);
    if (!nullToAbsent || translatedText != null) {
      map['translated_text'] = Variable<String>(translatedText);
    }
    if (!nullToAbsent || charStart != null) {
      map['char_start'] = Variable<int>(charStart);
    }
    if (!nullToAbsent || charEnd != null) {
      map['char_end'] = Variable<int>(charEnd);
    }
    if (!nullToAbsent || wordMapJson != null) {
      map['word_map_json'] = Variable<String>(wordMapJson);
    }
    return map;
  }

  LocalFragmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalFragmentsCompanion(
      id: Value(id),
      blockId: Value(blockId),
      fragmentOrder: Value(fragmentOrder),
      originalText: Value(originalText),
      translatedText: translatedText == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedText),
      charStart: charStart == null && nullToAbsent
          ? const Value.absent()
          : Value(charStart),
      charEnd: charEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(charEnd),
      wordMapJson: wordMapJson == null && nullToAbsent
          ? const Value.absent()
          : Value(wordMapJson),
    );
  }

  factory LocalFragment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFragment(
      id: serializer.fromJson<int>(json['id']),
      blockId: serializer.fromJson<int>(json['blockId']),
      fragmentOrder: serializer.fromJson<int>(json['fragmentOrder']),
      originalText: serializer.fromJson<String>(json['originalText']),
      translatedText: serializer.fromJson<String?>(json['translatedText']),
      charStart: serializer.fromJson<int?>(json['charStart']),
      charEnd: serializer.fromJson<int?>(json['charEnd']),
      wordMapJson: serializer.fromJson<String?>(json['wordMapJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'blockId': serializer.toJson<int>(blockId),
      'fragmentOrder': serializer.toJson<int>(fragmentOrder),
      'originalText': serializer.toJson<String>(originalText),
      'translatedText': serializer.toJson<String?>(translatedText),
      'charStart': serializer.toJson<int?>(charStart),
      'charEnd': serializer.toJson<int?>(charEnd),
      'wordMapJson': serializer.toJson<String?>(wordMapJson),
    };
  }

  LocalFragment copyWith({
    int? id,
    int? blockId,
    int? fragmentOrder,
    String? originalText,
    Value<String?> translatedText = const Value.absent(),
    Value<int?> charStart = const Value.absent(),
    Value<int?> charEnd = const Value.absent(),
    Value<String?> wordMapJson = const Value.absent(),
  }) => LocalFragment(
    id: id ?? this.id,
    blockId: blockId ?? this.blockId,
    fragmentOrder: fragmentOrder ?? this.fragmentOrder,
    originalText: originalText ?? this.originalText,
    translatedText: translatedText.present
        ? translatedText.value
        : this.translatedText,
    charStart: charStart.present ? charStart.value : this.charStart,
    charEnd: charEnd.present ? charEnd.value : this.charEnd,
    wordMapJson: wordMapJson.present ? wordMapJson.value : this.wordMapJson,
  );
  LocalFragment copyWithCompanion(LocalFragmentsCompanion data) {
    return LocalFragment(
      id: data.id.present ? data.id.value : this.id,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      fragmentOrder: data.fragmentOrder.present
          ? data.fragmentOrder.value
          : this.fragmentOrder,
      originalText: data.originalText.present
          ? data.originalText.value
          : this.originalText,
      translatedText: data.translatedText.present
          ? data.translatedText.value
          : this.translatedText,
      charStart: data.charStart.present ? data.charStart.value : this.charStart,
      charEnd: data.charEnd.present ? data.charEnd.value : this.charEnd,
      wordMapJson: data.wordMapJson.present
          ? data.wordMapJson.value
          : this.wordMapJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFragment(')
          ..write('id: $id, ')
          ..write('blockId: $blockId, ')
          ..write('fragmentOrder: $fragmentOrder, ')
          ..write('originalText: $originalText, ')
          ..write('translatedText: $translatedText, ')
          ..write('charStart: $charStart, ')
          ..write('charEnd: $charEnd, ')
          ..write('wordMapJson: $wordMapJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    blockId,
    fragmentOrder,
    originalText,
    translatedText,
    charStart,
    charEnd,
    wordMapJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFragment &&
          other.id == this.id &&
          other.blockId == this.blockId &&
          other.fragmentOrder == this.fragmentOrder &&
          other.originalText == this.originalText &&
          other.translatedText == this.translatedText &&
          other.charStart == this.charStart &&
          other.charEnd == this.charEnd &&
          other.wordMapJson == this.wordMapJson);
}

class LocalFragmentsCompanion extends UpdateCompanion<LocalFragment> {
  final Value<int> id;
  final Value<int> blockId;
  final Value<int> fragmentOrder;
  final Value<String> originalText;
  final Value<String?> translatedText;
  final Value<int?> charStart;
  final Value<int?> charEnd;
  final Value<String?> wordMapJson;
  const LocalFragmentsCompanion({
    this.id = const Value.absent(),
    this.blockId = const Value.absent(),
    this.fragmentOrder = const Value.absent(),
    this.originalText = const Value.absent(),
    this.translatedText = const Value.absent(),
    this.charStart = const Value.absent(),
    this.charEnd = const Value.absent(),
    this.wordMapJson = const Value.absent(),
  });
  LocalFragmentsCompanion.insert({
    this.id = const Value.absent(),
    required int blockId,
    required int fragmentOrder,
    required String originalText,
    this.translatedText = const Value.absent(),
    this.charStart = const Value.absent(),
    this.charEnd = const Value.absent(),
    this.wordMapJson = const Value.absent(),
  }) : blockId = Value(blockId),
       fragmentOrder = Value(fragmentOrder),
       originalText = Value(originalText);
  static Insertable<LocalFragment> custom({
    Expression<int>? id,
    Expression<int>? blockId,
    Expression<int>? fragmentOrder,
    Expression<String>? originalText,
    Expression<String>? translatedText,
    Expression<int>? charStart,
    Expression<int>? charEnd,
    Expression<String>? wordMapJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (blockId != null) 'block_id': blockId,
      if (fragmentOrder != null) 'fragment_order': fragmentOrder,
      if (originalText != null) 'original_text': originalText,
      if (translatedText != null) 'translated_text': translatedText,
      if (charStart != null) 'char_start': charStart,
      if (charEnd != null) 'char_end': charEnd,
      if (wordMapJson != null) 'word_map_json': wordMapJson,
    });
  }

  LocalFragmentsCompanion copyWith({
    Value<int>? id,
    Value<int>? blockId,
    Value<int>? fragmentOrder,
    Value<String>? originalText,
    Value<String?>? translatedText,
    Value<int?>? charStart,
    Value<int?>? charEnd,
    Value<String?>? wordMapJson,
  }) {
    return LocalFragmentsCompanion(
      id: id ?? this.id,
      blockId: blockId ?? this.blockId,
      fragmentOrder: fragmentOrder ?? this.fragmentOrder,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      charStart: charStart ?? this.charStart,
      charEnd: charEnd ?? this.charEnd,
      wordMapJson: wordMapJson ?? this.wordMapJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<int>(blockId.value);
    }
    if (fragmentOrder.present) {
      map['fragment_order'] = Variable<int>(fragmentOrder.value);
    }
    if (originalText.present) {
      map['original_text'] = Variable<String>(originalText.value);
    }
    if (translatedText.present) {
      map['translated_text'] = Variable<String>(translatedText.value);
    }
    if (charStart.present) {
      map['char_start'] = Variable<int>(charStart.value);
    }
    if (charEnd.present) {
      map['char_end'] = Variable<int>(charEnd.value);
    }
    if (wordMapJson.present) {
      map['word_map_json'] = Variable<String>(wordMapJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFragmentsCompanion(')
          ..write('id: $id, ')
          ..write('blockId: $blockId, ')
          ..write('fragmentOrder: $fragmentOrder, ')
          ..write('originalText: $originalText, ')
          ..write('translatedText: $translatedText, ')
          ..write('charStart: $charStart, ')
          ..write('charEnd: $charEnd, ')
          ..write('wordMapJson: $wordMapJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalBooksTable localBooks = $LocalBooksTable(this);
  late final $LocalBlocksTable localBlocks = $LocalBlocksTable(this);
  late final $LocalFragmentsTable localFragments = $LocalFragmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localBooks,
    localBlocks,
    localFragments,
  ];
}

typedef $$LocalBooksTableCreateCompanionBuilder =
    LocalBooksCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> author,
      Value<int?> totalPages,
      Value<String?> language,
      Value<String?> coverUrl,
      required DateTime downloadedAt,
    });
typedef $$LocalBooksTableUpdateCompanionBuilder =
    LocalBooksCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> author,
      Value<int?> totalPages,
      Value<String?> language,
      Value<String?> coverUrl,
      Value<DateTime> downloadedAt,
    });

class $$LocalBooksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBooksTable> {
  $$LocalBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBooksTable> {
  $$LocalBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBooksTable> {
  $$LocalBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );
}

class $$LocalBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBooksTable,
          LocalBook,
          $$LocalBooksTableFilterComposer,
          $$LocalBooksTableOrderingComposer,
          $$LocalBooksTableAnnotationComposer,
          $$LocalBooksTableCreateCompanionBuilder,
          $$LocalBooksTableUpdateCompanionBuilder,
          (
            LocalBook,
            BaseReferences<_$AppDatabase, $LocalBooksTable, LocalBook>,
          ),
          LocalBook,
          PrefetchHooks Function()
        > {
  $$LocalBooksTableTableManager(_$AppDatabase db, $LocalBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> totalPages = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<DateTime> downloadedAt = const Value.absent(),
              }) => LocalBooksCompanion(
                id: id,
                title: title,
                author: author,
                totalPages: totalPages,
                language: language,
                coverUrl: coverUrl,
                downloadedAt: downloadedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> author = const Value.absent(),
                Value<int?> totalPages = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                required DateTime downloadedAt,
              }) => LocalBooksCompanion.insert(
                id: id,
                title: title,
                author: author,
                totalPages: totalPages,
                language: language,
                coverUrl: coverUrl,
                downloadedAt: downloadedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBooksTable,
      LocalBook,
      $$LocalBooksTableFilterComposer,
      $$LocalBooksTableOrderingComposer,
      $$LocalBooksTableAnnotationComposer,
      $$LocalBooksTableCreateCompanionBuilder,
      $$LocalBooksTableUpdateCompanionBuilder,
      (LocalBook, BaseReferences<_$AppDatabase, $LocalBooksTable, LocalBook>),
      LocalBook,
      PrefetchHooks Function()
    >;
typedef $$LocalBlocksTableCreateCompanionBuilder =
    LocalBlocksCompanion Function({
      Value<int> id,
      required int bookId,
      Value<int?> pageNumber,
      Value<int?> sequenceOrder,
      required String blockType,
      Value<String?> originalContent,
      Value<String?> imageUrl,
    });
typedef $$LocalBlocksTableUpdateCompanionBuilder =
    LocalBlocksCompanion Function({
      Value<int> id,
      Value<int> bookId,
      Value<int?> pageNumber,
      Value<int?> sequenceOrder,
      Value<String> blockType,
      Value<String?> originalContent,
      Value<String?> imageUrl,
    });

class $$LocalBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $LocalBlocksTable> {
  $$LocalBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceOrder => $composableBuilder(
    column: $table.sequenceOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockType => $composableBuilder(
    column: $table.blockType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalContent => $composableBuilder(
    column: $table.originalContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalBlocksTable> {
  $$LocalBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceOrder => $composableBuilder(
    column: $table.sequenceOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockType => $composableBuilder(
    column: $table.blockType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalContent => $composableBuilder(
    column: $table.originalContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalBlocksTable> {
  $$LocalBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequenceOrder => $composableBuilder(
    column: $table.sequenceOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockType =>
      $composableBuilder(column: $table.blockType, builder: (column) => column);

  GeneratedColumn<String> get originalContent => $composableBuilder(
    column: $table.originalContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);
}

class $$LocalBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalBlocksTable,
          LocalBlock,
          $$LocalBlocksTableFilterComposer,
          $$LocalBlocksTableOrderingComposer,
          $$LocalBlocksTableAnnotationComposer,
          $$LocalBlocksTableCreateCompanionBuilder,
          $$LocalBlocksTableUpdateCompanionBuilder,
          (
            LocalBlock,
            BaseReferences<_$AppDatabase, $LocalBlocksTable, LocalBlock>,
          ),
          LocalBlock,
          PrefetchHooks Function()
        > {
  $$LocalBlocksTableTableManager(_$AppDatabase db, $LocalBlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<int?> sequenceOrder = const Value.absent(),
                Value<String> blockType = const Value.absent(),
                Value<String?> originalContent = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
              }) => LocalBlocksCompanion(
                id: id,
                bookId: bookId,
                pageNumber: pageNumber,
                sequenceOrder: sequenceOrder,
                blockType: blockType,
                originalContent: originalContent,
                imageUrl: imageUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bookId,
                Value<int?> pageNumber = const Value.absent(),
                Value<int?> sequenceOrder = const Value.absent(),
                required String blockType,
                Value<String?> originalContent = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
              }) => LocalBlocksCompanion.insert(
                id: id,
                bookId: bookId,
                pageNumber: pageNumber,
                sequenceOrder: sequenceOrder,
                blockType: blockType,
                originalContent: originalContent,
                imageUrl: imageUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalBlocksTable,
      LocalBlock,
      $$LocalBlocksTableFilterComposer,
      $$LocalBlocksTableOrderingComposer,
      $$LocalBlocksTableAnnotationComposer,
      $$LocalBlocksTableCreateCompanionBuilder,
      $$LocalBlocksTableUpdateCompanionBuilder,
      (
        LocalBlock,
        BaseReferences<_$AppDatabase, $LocalBlocksTable, LocalBlock>,
      ),
      LocalBlock,
      PrefetchHooks Function()
    >;
typedef $$LocalFragmentsTableCreateCompanionBuilder =
    LocalFragmentsCompanion Function({
      Value<int> id,
      required int blockId,
      required int fragmentOrder,
      required String originalText,
      Value<String?> translatedText,
      Value<int?> charStart,
      Value<int?> charEnd,
      Value<String?> wordMapJson,
    });
typedef $$LocalFragmentsTableUpdateCompanionBuilder =
    LocalFragmentsCompanion Function({
      Value<int> id,
      Value<int> blockId,
      Value<int> fragmentOrder,
      Value<String> originalText,
      Value<String?> translatedText,
      Value<int?> charStart,
      Value<int?> charEnd,
      Value<String?> wordMapJson,
    });

class $$LocalFragmentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFragmentsTable> {
  $$LocalFragmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fragmentOrder => $composableBuilder(
    column: $table.fragmentOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charStart => $composableBuilder(
    column: $table.charStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charEnd => $composableBuilder(
    column: $table.charEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wordMapJson => $composableBuilder(
    column: $table.wordMapJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalFragmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFragmentsTable> {
  $$LocalFragmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fragmentOrder => $composableBuilder(
    column: $table.fragmentOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charStart => $composableBuilder(
    column: $table.charStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charEnd => $composableBuilder(
    column: $table.charEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wordMapJson => $composableBuilder(
    column: $table.wordMapJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalFragmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFragmentsTable> {
  $$LocalFragmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<int> get fragmentOrder => $composableBuilder(
    column: $table.fragmentOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedText => $composableBuilder(
    column: $table.translatedText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charStart =>
      $composableBuilder(column: $table.charStart, builder: (column) => column);

  GeneratedColumn<int> get charEnd =>
      $composableBuilder(column: $table.charEnd, builder: (column) => column);

  GeneratedColumn<String> get wordMapJson => $composableBuilder(
    column: $table.wordMapJson,
    builder: (column) => column,
  );
}

class $$LocalFragmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalFragmentsTable,
          LocalFragment,
          $$LocalFragmentsTableFilterComposer,
          $$LocalFragmentsTableOrderingComposer,
          $$LocalFragmentsTableAnnotationComposer,
          $$LocalFragmentsTableCreateCompanionBuilder,
          $$LocalFragmentsTableUpdateCompanionBuilder,
          (
            LocalFragment,
            BaseReferences<_$AppDatabase, $LocalFragmentsTable, LocalFragment>,
          ),
          LocalFragment,
          PrefetchHooks Function()
        > {
  $$LocalFragmentsTableTableManager(
    _$AppDatabase db,
    $LocalFragmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFragmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFragmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFragmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> blockId = const Value.absent(),
                Value<int> fragmentOrder = const Value.absent(),
                Value<String> originalText = const Value.absent(),
                Value<String?> translatedText = const Value.absent(),
                Value<int?> charStart = const Value.absent(),
                Value<int?> charEnd = const Value.absent(),
                Value<String?> wordMapJson = const Value.absent(),
              }) => LocalFragmentsCompanion(
                id: id,
                blockId: blockId,
                fragmentOrder: fragmentOrder,
                originalText: originalText,
                translatedText: translatedText,
                charStart: charStart,
                charEnd: charEnd,
                wordMapJson: wordMapJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int blockId,
                required int fragmentOrder,
                required String originalText,
                Value<String?> translatedText = const Value.absent(),
                Value<int?> charStart = const Value.absent(),
                Value<int?> charEnd = const Value.absent(),
                Value<String?> wordMapJson = const Value.absent(),
              }) => LocalFragmentsCompanion.insert(
                id: id,
                blockId: blockId,
                fragmentOrder: fragmentOrder,
                originalText: originalText,
                translatedText: translatedText,
                charStart: charStart,
                charEnd: charEnd,
                wordMapJson: wordMapJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalFragmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalFragmentsTable,
      LocalFragment,
      $$LocalFragmentsTableFilterComposer,
      $$LocalFragmentsTableOrderingComposer,
      $$LocalFragmentsTableAnnotationComposer,
      $$LocalFragmentsTableCreateCompanionBuilder,
      $$LocalFragmentsTableUpdateCompanionBuilder,
      (
        LocalFragment,
        BaseReferences<_$AppDatabase, $LocalFragmentsTable, LocalFragment>,
      ),
      LocalFragment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalBooksTableTableManager get localBooks =>
      $$LocalBooksTableTableManager(_db, _db.localBooks);
  $$LocalBlocksTableTableManager get localBlocks =>
      $$LocalBlocksTableTableManager(_db, _db.localBlocks);
  $$LocalFragmentsTableTableManager get localFragments =>
      $$LocalFragmentsTableTableManager(_db, _db.localFragments);
}
