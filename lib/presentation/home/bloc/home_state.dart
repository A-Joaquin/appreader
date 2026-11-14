import 'package:equatable/equatable.dart';

import '../../../data/models/book_model.dart';
import '../../../data/repositories/book_repository.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<Book> books;
  final String? error;

  /// De dónde salió [books]; la pantalla avisa si no es [LibrarySource.online].
  final LibrarySource source;

  /// Por qué falló la red cuando [source] es [LibrarySource.offlineFallback].
  final String? offlineReason;

  /// Preferencia guardada: cargar en línea también con datos móviles.
  final bool mobileDataAllowed;

  const HomeState({
    this.status = HomeStatus.initial,
    this.books = const [],
    this.error,
    this.source = LibrarySource.online,
    this.offlineReason,
    this.mobileDataAllowed = false,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<Book>? books,
    String? error,
    LibrarySource? source,
    String? offlineReason,
    bool? mobileDataAllowed,
  }) {
    return HomeState(
      status: status ?? this.status,
      books: books ?? this.books,
      error: error,
      source: source ?? this.source,
      offlineReason: offlineReason,
      mobileDataAllowed: mobileDataAllowed ?? this.mobileDataAllowed,
    );
  }

  @override
  List<Object?> get props =>
      [status, books, error, source, offlineReason, mobileDataAllowed];
}
