import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs({super.key});

  @override
  Widget build(BuildContext context) {
    const List<String> categories = <String>[
      'All',
      'Coffee',
      'Food',
      'Desserts',
      'Cold Drinks',
    ];

    return SizedBox(
      height: AppSizes.categoryTabHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: AppSpacing.sm);
        },
        itemBuilder: (BuildContext context, int index) {
          return ChoiceChip(
            label: Text(categories[index]),
            selected: index == 0,
            onSelected: (_) {},
          );
        },
      ),
    );
  }
}
