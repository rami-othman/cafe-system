import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/discount_list_item.dart';
import 'discounts_state.dart';

class DiscountsCubit extends Cubit<DiscountsState> {
  DiscountsCubit() : super(const DiscountsState());

  static const int pageSize = 4;

  static const List<DiscountListItem> _discounts = <DiscountListItem>[
    DiscountListItem(
      id: 'morning-rush',
      name: 'Morning Rush 15%',
      secondaryLabel: 'Code: MRNG15',
      type: 'Percentage',
      displayValue: '15% off',
      conditions: 'Min. \$10 spent',
      validPeriodPrimary: 'Oct 1 - Oct 31',
      validPeriodSecondary: '7:00 AM - 10:00 AM',
      status: DiscountStatus.active,
      usageCount: 128,
      estimatedSavedValue: '\$192.00',
    ),
    DiscountListItem(
      id: 'student',
      name: 'Student Discount',
      secondaryLabel: 'Automatic',
      type: 'Fixed Amount',
      displayValue: '\$2.00 off',
      conditions: 'Requires Student ID tag',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 164,
      estimatedSavedValue: '\$328.00',
    ),
    DiscountListItem(
      id: 'holiday-special',
      name: 'Holiday Special',
      secondaryLabel: 'Code: HOLIDAY24',
      type: 'Percentage',
      displayValue: '20% off',
      conditions: 'Any pastry + drink',
      validPeriodPrimary: 'Dec 15 - Dec 31',
      status: DiscountStatus.scheduled,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'summer-coolers',
      name: 'Summer Coolers',
      secondaryLabel: 'Code: SUMMER',
      type: 'BOGO',
      displayValue: 'Buy 1 Get 1',
      conditions: 'Iced beverages only',
      validPeriodPrimary: 'Jun 1 - Aug 31',
      status: DiscountStatus.expired,
      usageCount: 94,
      estimatedSavedValue: '\$188.00',
    ),
    DiscountListItem(
      id: 'weekday-lunch',
      name: 'Weekday Lunch',
      secondaryLabel: 'Code: LUNCH10',
      type: 'Percentage',
      displayValue: '10% off',
      conditions: 'Between 12:00 PM - 3:00 PM',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 46,
      estimatedSavedValue: '\$74.00',
    ),
    DiscountListItem(
      id: 'first-order',
      name: 'First Order',
      secondaryLabel: 'Automatic',
      type: 'Fixed Amount',
      displayValue: '\$3.00 off',
      conditions: 'New customers only',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 28,
      estimatedSavedValue: '\$84.00',
    ),
    DiscountListItem(
      id: 'pastry-pairing',
      name: 'Pastry Pairing',
      secondaryLabel: 'Code: PAIR5',
      type: 'Percentage',
      displayValue: '5% off',
      conditions: 'Coffee + pastry',
      validPeriodPrimary: 'Nov 1 - Nov 30',
      status: DiscountStatus.scheduled,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'tea-time',
      name: 'Tea Time Treat',
      secondaryLabel: 'Code: TEA15',
      type: 'Percentage',
      displayValue: '15% off',
      conditions: 'Selected teas',
      validPeriodPrimary: 'Mar 1 - Mar 31',
      status: DiscountStatus.expired,
      usageCount: 31,
      estimatedSavedValue: '\$46.50',
    ),
    DiscountListItem(
      id: 'loyalty-thanks',
      name: 'Loyalty Thanks',
      secondaryLabel: 'Automatic',
      type: 'Fixed Amount',
      displayValue: '\$1.50 off',
      conditions: 'Gold members only',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 36,
      estimatedSavedValue: '\$54.00',
    ),
    DiscountListItem(
      id: 'friday-fizz',
      name: 'Friday Fizz',
      secondaryLabel: 'Code: FIZZ',
      type: 'BOGO',
      displayValue: 'Buy 1 Get 1',
      conditions: 'Sparkling drinks',
      validPeriodPrimary: 'Every Friday',
      status: DiscountStatus.active,
      usageCount: 20,
      estimatedSavedValue: '\$40.00',
    ),
    DiscountListItem(
      id: 'winter-warmer',
      name: 'Winter Warmer',
      secondaryLabel: 'Code: WARM10',
      type: 'Percentage',
      displayValue: '10% off',
      conditions: 'Hot beverages',
      validPeriodPrimary: 'Jan 1 - Feb 28',
      status: DiscountStatus.draft,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'birthday-reward',
      name: 'Birthday Reward',
      secondaryLabel: 'Automatic',
      type: 'Fixed Amount',
      displayValue: '\$5.00 off',
      conditions: 'Birthday month',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 15,
      estimatedSavedValue: '\$75.00',
    ),
    DiscountListItem(
      id: 'office-catering',
      name: 'Office Catering',
      secondaryLabel: 'Code: OFFICE',
      type: 'Percentage',
      displayValue: '12% off',
      conditions: 'Orders over \$75',
      validPeriodPrimary: 'Sep 1 - Sep 30',
      status: DiscountStatus.scheduled,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'weekend-brunch',
      name: 'Weekend Brunch',
      secondaryLabel: 'Code: BRUNCH',
      type: 'Percentage',
      displayValue: '10% off',
      conditions: 'Saturday and Sunday',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 17,
      estimatedSavedValue: '\$34.00',
    ),
    DiscountListItem(
      id: 'rainy-day',
      name: 'Rainy Day Perk',
      secondaryLabel: 'Code: RAINY',
      type: 'Fixed Amount',
      displayValue: '\$1.00 off',
      conditions: 'Mobile orders',
      validPeriodPrimary: 'Apr 1 - Apr 30',
      status: DiscountStatus.expired,
      usageCount: 12,
      estimatedSavedValue: '\$12.00',
    ),
    DiscountListItem(
      id: 'bean-bag',
      name: 'Bean Bag Bundle',
      secondaryLabel: 'Code: BEANS',
      type: 'Fixed Amount',
      displayValue: '\$4.00 off',
      conditions: 'Two coffee bags',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 9,
      estimatedSavedValue: '\$36.00',
    ),
    DiscountListItem(
      id: 'afternoon-pickup',
      name: 'Afternoon Pickup',
      secondaryLabel: 'Code: PICKUP',
      type: 'Percentage',
      displayValue: '8% off',
      conditions: 'Order ahead pickup',
      validPeriodPrimary: '2:00 PM - 5:00 PM',
      status: DiscountStatus.active,
      usageCount: 11,
      estimatedSavedValue: '\$17.60',
    ),
    DiscountListItem(
      id: 'new-menu',
      name: 'New Menu Launch',
      secondaryLabel: 'Code: NEWMENU',
      type: 'Percentage',
      displayValue: '20% off',
      conditions: 'Featured menu items',
      validPeriodPrimary: 'Oct 15 - Oct 22',
      status: DiscountStatus.scheduled,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'family-pack',
      name: 'Family Pack',
      secondaryLabel: 'Code: FAMILY',
      type: 'BOGO',
      displayValue: 'Buy 1 Get 1',
      conditions: 'Kids drinks',
      validPeriodPrimary: 'Aug 1 - Aug 31',
      status: DiscountStatus.expired,
      usageCount: 8,
      estimatedSavedValue: '\$16.00',
    ),
    DiscountListItem(
      id: 'late-night',
      name: 'Late Night',
      secondaryLabel: 'Code: NIGHT',
      type: 'Percentage',
      displayValue: '10% off',
      conditions: 'After 8:00 PM',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.draft,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'staff-friends',
      name: 'Staff Friends',
      secondaryLabel: 'Code: FRIENDS',
      type: 'Fixed Amount',
      displayValue: '\$2.50 off',
      conditions: 'Staff referral',
      validPeriodPrimary: 'Always Valid',
      status: DiscountStatus.active,
      usageCount: 6,
      estimatedSavedValue: '\$15.00',
    ),
    DiscountListItem(
      id: 'festival-treat',
      name: 'Festival Treat',
      secondaryLabel: 'Code: FESTIVE',
      type: 'Percentage',
      displayValue: '15% off',
      conditions: 'Any seasonal drink',
      validPeriodPrimary: 'Dec 1 - Dec 14',
      status: DiscountStatus.scheduled,
      usageCount: 0,
      estimatedSavedValue: '\$0.00',
    ),
    DiscountListItem(
      id: 'monday-mug',
      name: 'Monday Mug',
      secondaryLabel: 'Code: MONDAY',
      type: 'Fixed Amount',
      displayValue: '\$1.00 off',
      conditions: 'Reusable mug',
      validPeriodPrimary: 'Every Monday',
      status: DiscountStatus.active,
      usageCount: 5,
      estimatedSavedValue: '\$5.00',
    ),
    DiscountListItem(
      id: 'spring-sips',
      name: 'Spring Sips',
      secondaryLabel: 'Code: SPRING',
      type: 'Percentage',
      displayValue: '10% off',
      conditions: 'Cold brew drinks',
      validPeriodPrimary: 'Mar 1 - May 31',
      status: DiscountStatus.expired,
      usageCount: 2,
      estimatedSavedValue: '\$4.00',
    ),
  ];

  List<DiscountListItem> get filteredDiscounts {
    final String query = state.searchQuery.trim().toLowerCase();
    return _discounts
        .where((DiscountListItem discount) {
          final bool matchesStatus =
              state.selectedStatus == null ||
              discount.status == state.selectedStatus;
          final bool matchesSearch =
              query.isEmpty ||
              discount.name.toLowerCase().contains(query) ||
              discount.secondaryLabel.toLowerCase().contains(query) ||
              discount.type.toLowerCase().contains(query) ||
              discount.conditions.toLowerCase().contains(query);
          return matchesStatus && matchesSearch;
        })
        .toList(growable: false);
  }

  int get totalPages {
    final int pages = (filteredDiscounts.length / pageSize).ceil();
    return pages < 1 ? 1 : pages;
  }

  List<DiscountListItem> get currentPageDiscounts {
    final List<DiscountListItem> discounts = filteredDiscounts;
    final int start = (state.currentPage - 1) * pageSize;
    if (start >= discounts.length) {
      return const <DiscountListItem>[];
    }
    final int end = (start + pageSize).clamp(0, discounts.length);
    return discounts.sublist(start, end);
  }

  void updateSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query, currentPage: 1));
  }

  void updateStatus(DiscountStatus? status) {
    emit(
      state.copyWith(
        selectedStatus: status,
        clearSelectedStatus: status == null,
        currentPage: 1,
      ),
    );
  }

  void changePage(int page) {
    if (page < 1 || page > totalPages || page == state.currentPage) {
      return;
    }
    emit(state.copyWith(currentPage: page));
  }
}
