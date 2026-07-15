import 'package:equatable/equatable.dart';

import '../models/discount_list_item.dart';

class DiscountsState extends Equatable {
  const DiscountsState({
    this.searchQuery = '',
    this.selectedStatus,
    this.currentPage = 1,
  });

  final String searchQuery;
  final DiscountStatus? selectedStatus;
  final int currentPage;

  DiscountsState copyWith({
    String? searchQuery,
    DiscountStatus? selectedStatus,
    int? currentPage,
    bool clearSelectedStatus = false,
  }) {
    return DiscountsState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: clearSelectedStatus
          ? null
          : selectedStatus ?? this.selectedStatus,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    searchQuery,
    selectedStatus,
    currentPage,
  ];
}
