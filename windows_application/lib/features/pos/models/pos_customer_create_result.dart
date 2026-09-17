import 'package:equatable/equatable.dart';

import 'customer.dart';

class PosCustomerCreateResult extends Equatable {
  const PosCustomerCreateResult({
    required this.customer,
    required this.attachedToOrder,
    this.attachmentFailed = false,
  });

  final Customer customer;
  final bool attachedToOrder;
  final bool attachmentFailed;

  @override
  List<Object> get props => <Object>[
    customer,
    attachedToOrder,
    attachmentFailed,
  ];
}
