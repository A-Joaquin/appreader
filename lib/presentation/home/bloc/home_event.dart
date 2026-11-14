import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Carga la biblioteca. Con datos móviles solo va a la red si el usuario lo
/// permitió siempre, o si [forceOnline] (botón «Cargar en línea» de esta vez).
class LoadBooks extends HomeEvent {
  const LoadBooks({this.forceOnline = false});

  final bool forceOnline;

  @override
  List<Object?> get props => [forceOnline];
}

/// Cambia la preferencia «usar datos móviles para ver libros en línea» y
/// recarga la biblioteca.
class SetMobileDataAllowed extends HomeEvent {
  const SetMobileDataAllowed(this.allowed);

  final bool allowed;

  @override
  List<Object?> get props => [allowed];
}
