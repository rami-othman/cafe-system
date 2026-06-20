import 'package:equatable/equatable.dart';

class OrderTimelineEvent extends Equatable {
  const OrderTimelineEvent({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final String title;
  final String subtitle;
  final DateTime time;

  @override
  List<Object?> get props => <Object?>[title, subtitle, time];
}
