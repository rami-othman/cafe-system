import 'package:equatable/equatable.dart';

enum PosStatus { initial }

class PosState extends Equatable {
  const PosState({this.status = PosStatus.initial});

  final PosStatus status;

  @override
  List<Object> get props => <Object>[status];
}
