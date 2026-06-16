import 'package:equatable/equatable.dart';

import '../../../data/models/book_model.dart';

enum HomeStatus { initial, loading, success, failure }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<Book> books;
  final String? error;

  const HomeState({
    this.status = HomeStatus.initial,
    this.books = const [],
    this.error,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<Book>? books,
    String? error,
  }) {
    return HomeState(
      status: status ?? this.status,
      books: books ?? this.books,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, books, error];
}
