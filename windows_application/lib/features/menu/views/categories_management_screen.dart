import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import 'menu_placeholder_screen.dart';

class CategoriesManagementScreen extends StatelessWidget {
  const CategoriesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => MenuPlaceholderScreen(
    title: 'Categories',
    breadcrumbs: <AppBreadcrumbItem>[
      AppBreadcrumbItem(
        label: 'Menu',
        onTap: () => context.go(AppRoutes.menu),
        key: const Key('breadcrumb-menu'),
      ),
    ],
  );
}
