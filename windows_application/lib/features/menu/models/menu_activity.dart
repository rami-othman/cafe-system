import 'package:equatable/equatable.dart';

class MenuActivity extends Equatable {
  const MenuActivity({
    required this.id,
    required this.activity,
    required this.user,
    required this.dateTime,
    required this.status,
  });

  final String id;
  final String activity;
  final String user;
  final DateTime dateTime;
  final String status;

  @override
  List<Object?> get props => <Object?>[id, activity, user, dateTime, status];
}
