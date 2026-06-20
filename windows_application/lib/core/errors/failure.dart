import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => <Object?>[message, code];
}
