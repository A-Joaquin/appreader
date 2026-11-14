import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/mobile_data.dart';
import '../../../data/repositories/book_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final BookRepository repository;

  HomeBloc(this.repository) : super(const HomeState()) {
    on<LoadBooks>(_onLoadBooks);
    on<SetMobileDataAllowed>(_onSetMobileDataAllowed);
  }

  Future<void> _onLoadBooks(LoadBooks event, Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    final allowed = await MobileData.isAllowed();
    final onMobile = await MobileData.isOnMobileData();
    try {
      final result = await repository.loadLibrary(
          online: !onMobile || allowed || event.forceOnline);
      emit(state.copyWith(
        status: HomeStatus.success,
        books: result.books,
        source: result.source,
        offlineReason: result.reason,
        mobileDataAllowed: allowed,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        error: 'No se pudieron cargar los libros: ${describeNetworkError(e)}.',
        mobileDataAllowed: allowed,
      ));
    }
  }

  Future<void> _onSetMobileDataAllowed(
      SetMobileDataAllowed event, Emitter<HomeState> emit) async {
    await MobileData.setAllowed(event.allowed);
    add(const LoadBooks());
  }
}
