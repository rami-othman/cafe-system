import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import 'pos_category_tabs.dart';
import 'pos_search_bar.dart';
import 'product_grid.dart';

class PosProductArea extends StatelessWidget {
  const PosProductArea({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double searchWidth = math.min(
          constraints.maxWidth,
          AppSizes.posSearchWidth,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ProductAreaHeader(searchWidth: searchWidth),
            const SizedBox(height: AppSpacing.xl),
            const Expanded(child: ProductGrid()),
          ],
        );
      },
    );
  }
}

class _ProductAreaHeader extends StatelessWidget {
  const _ProductAreaHeader({required this.searchWidth});

  final double searchWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PosSearchBar(width: searchWidth),
        const SizedBox(height: AppSpacing.lg),
        const PosCategoryTabs(),
      ],
    );
  }
}
