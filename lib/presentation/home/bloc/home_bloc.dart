import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/book_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final BookRepository repository;

  HomeBloc(this.repository) : super(const HomeState()) {
    on<LoadBooks>(_onLoadBooks);
  }

  Future<void> _onLoadBooks(LoadBooks event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final books = await repository.getBooks();
      emit(state.copyWith(status: HomeStatus.success, books: books));
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.failure, error: e.toString()));
    }
  }
}
