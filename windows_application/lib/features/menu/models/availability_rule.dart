import 'package:equatable/equatable.dart';

import 'menu_enums.dart';

class AvailabilityRule extends Equatable {
  const AvailabilityRule({
    required this.productId,
    required this.activeDays,
    required this.startTime,
    required this.endTime,
    required this.branchIds,
    required this.channels,
    required this.isTemporarilyUnavailable,
    required this.isSoldOut,
  });

  final String productId;
  final List<int> activeDays;
  final String startTime;
  final String endTime;
  final List<String> branchIds;
  final List<ChannelType> channels;
  final bool isTemporarilyUnavailable;
  final bool isSoldOut;

  @override
  List<Object?> get props => <Object?>[
    productId,
    activeDays,
    startTime,
    endTime,
    branchIds,
    channels,
    isTemporarilyUnavailable,
    isSoldOut,
  ];
}
