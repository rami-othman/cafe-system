import 'package:equatable/equatable.dart';

class BranchPriceOverride extends Equatable {
  const BranchPriceOverride({
    required this.branchId,
    required this.branchName,
    required this.productId,
    required this.overridePrice,
    this.variantId,
  });

  final String branchId;
  final String branchName;
  final String productId;
  final String? variantId;
  final double overridePrice;

  @override
  List<Object?> get props => <Object?>[
    branchId,
    branchName,
    productId,
    variantId,
    overridePrice,
  ];
}
