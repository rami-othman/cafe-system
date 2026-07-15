import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../controllers/menu_cubit.dart';
import '../controllers/menu_state.dart';
import '../models/menu_product.dart';
import '../widgets/product_filter_bar.dart';
import '../widgets/products_table.dart';

class ProductsListScreen extends StatelessWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MenuCubit, MenuState>(
      builder: (BuildContext context, MenuState state) {
        if (state.loadingStatus == MenuLoadingStatus.initial ||
            state.loadingStatus == MenuLoadingStatus.loading) {
          return const DesktopPageLayout(child: AppLoading());
        }

        if (state.loadingStatus == MenuLoadingStatus.failure) {
          return DesktopPageLayout(
            child: AppEmptyState(
              message: state.errorMessage ?? 'Could not load products.',
              icon: Icons.inventory_2_outlined,
            ),
          );
        }

        final MenuCubit cubit = context.read<MenuCubit>();
        final List<MenuProduct> products = _visibleProducts(
          cubit.getFilteredProducts(),
        );

        return DesktopPageLayout(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.menuContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _ProductsPageHeader(),
                  const SizedBox(height: AppSpacing.lg),
                  ProductFilterBar(onSearchChanged: cubit.updateSearchQuery),
                  const SizedBox(height: AppSpacing.lg),
                  if (products.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: AppEmptyState(
                        message: 'No products match these filters.',
                        icon: Icons.search_off_outlined,
                      ),
                    )
                  else
                    ProductsTable(products: products),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<MenuProduct> _visibleProducts(List<MenuProduct> products) {
    const List<String> visibleIds = <String>[
      'espresso',
      'latte',
      'cappuccino',
      'croissant',
      'morning-combo',
    ];
    final Map<String, MenuProduct> productsById = <String, MenuProduct>{
      for (final MenuProduct product in products) product.id: product,
    };

    return visibleIds
        .map((String id) => productsById[id])
        .whereType<MenuProduct>()
        .toList(growable: false);
  }
}

class _ProductsPageHeader extends StatelessWidget {
  const _ProductsPageHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppBreadcrumbs(
              items: <AppBreadcrumbItem>[
                AppBreadcrumbItem(
                  label: 'Menu',
                  onTap: () => context.go(AppRoutes.menu),
                  key: const Key('breadcrumb-menu'),
                ),
                const AppBreadcrumbItem(label: 'Products'),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Products',
              style: AppTextStyles.displayMedium.copyWith(letterSpacing: -0.6),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manage your catalog, pricing, and availability.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );

        final Widget actions = Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            AppButton(
              label: 'Export',
              icon: Icons.download_outlined,
              variant: AppButtonVariant.outlined,
              onPressed: () {},
            ),
            AppButton(
              label: 'Add Product',
              icon: Icons.add,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.go(AppRoutes.menuProductCreate),
            ),
          ],
        );

        if (constraints.maxWidth < 660) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: AppSpacing.lg),
              actions,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.xl),
            actions,
          ],
        );
      },
    );
  }
}
