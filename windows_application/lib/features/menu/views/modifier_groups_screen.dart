import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_breadcrumbs.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/menu_cubit.dart';
import '../controllers/menu_state.dart';
import '../models/modifier_group.dart';
import '../widgets/modifier_group_card.dart';
import '../widgets/modifier_group_detail_panel.dart';

class ModifierGroupsScreen extends StatefulWidget {
  const ModifierGroupsScreen({super.key});

  @override
  State<ModifierGroupsScreen> createState() => _ModifierGroupsScreenState();
}

class _ModifierGroupsScreenState extends State<ModifierGroupsScreen> {
  String _searchQuery = '';
  String? _selectedGroupId;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: BlocBuilder<MenuCubit, MenuState>(
        builder: (BuildContext context, MenuState state) {
          if (state.loadingStatus == MenuLoadingStatus.loading ||
              state.loadingStatus == MenuLoadingStatus.initial) {
            return const AppLoading();
          }
          if (state.loadingStatus == MenuLoadingStatus.failure) {
            return AppEmptyState(
              message: state.errorMessage ?? 'Could not load modifier groups.',
              icon: Icons.error_outline,
            );
          }
          if (state.modifierGroups.isEmpty) {
            return const AppEmptyState(
              message: 'No modifier groups found.',
              icon: Icons.tune,
            );
          }

          final ModifierGroup selectedGroup = _selectedGroup(state);
          final List<ModifierGroup> visibleGroups = _visibleGroups(state);

          return SingleChildScrollView(
            padding: AppSpacing.allXxl,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.menuContentMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _PageHeader(
                      onNewGroup: () => _showPlaceholder(
                        'New modifier group creation is not implemented yet.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final Widget groupList = _GroupList(
                          groups: visibleGroups,
                          selectedGroupId: selectedGroup.id,
                          onSearchChanged: (String value) {
                            setState(() => _searchQuery = value);
                          },
                          onFilter: () => _showPlaceholder(
                            'Modifier filters are not implemented yet.',
                          ),
                          onSelected: (ModifierGroup group) {
                            setState(() => _selectedGroupId = group.id);
                          },
                          onMore: (ModifierGroup group) => _showPlaceholder(
                            '${group.name} actions are not implemented yet.',
                          ),
                        );
                        final Widget detail = ModifierGroupDetailPanel(
                          group: selectedGroup,
                          onEditGroup: () => _showPlaceholder(
                            'Editing modifier groups is not implemented yet.',
                          ),
                          onAddOption: () => _showPlaceholder(
                            'Adding modifier options is not implemented yet.',
                          ),
                          onManageLinks: () => _showPlaceholder(
                            'Managing product links is not implemented yet.',
                          ),
                          onOptionAction: (String action) => _showPlaceholder(
                            '$action is not implemented yet.',
                          ),
                          onRemoveProduct: (String product) => _showPlaceholder(
                            'Removing $product is not implemented yet.',
                          ),
                        );

                        if (constraints.maxWidth <
                            AppSizes.modifierGroupsStackBreakpoint) {
                          return Column(
                            children: <Widget>[
                              groupList,
                              const SizedBox(height: AppSpacing.lg),
                              detail,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: AppSizes.modifierGroupsListWidth,
                              child: groupList,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(child: detail),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  ModifierGroup _selectedGroup(MenuState state) {
    return state.modifierGroups.firstWhere(
      (ModifierGroup group) => group.id == _selectedGroupId,
      orElse: () => state.modifierGroups.first,
    );
  }

  List<ModifierGroup> _visibleGroups(MenuState state) {
    final String query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return state.modifierGroups;
    }
    return state.modifierGroups
        .where(
          (ModifierGroup group) => group.name.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _showPlaceholder(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onNewGroup});

  final VoidCallback onNewGroup;

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
                const AppBreadcrumbItem(label: 'Modifier Groups'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Modifier Groups', style: AppTextStyles.displayMedium),
          ],
        );
        final Widget button = AppButton(
          label: 'New Group',
          icon: Icons.add,
          variant: AppButtonVariant.accent,
          onPressed: onNewGroup,
        );

        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              heading,
              const SizedBox(height: AppSpacing.lg),
              button,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.lg),
            button,
          ],
        );
      },
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.selectedGroupId,
    required this.onSearchChanged,
    required this.onFilter,
    required this.onSelected,
    required this.onMore,
  });

  final List<ModifierGroup> groups;
  final String selectedGroupId;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilter;
  final ValueChanged<ModifierGroup> onSelected;
  final ValueChanged<ModifierGroup> onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AppCard(
          padding: AppSpacing.allSm,
          child: Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  key: const Key('modifier-group-search'),
                  hintText: 'Search modifier groups...',
                  prefixIcon: Icons.search,
                  onChanged: onSearchChanged,
                ),
              ),
              IconButton(
                onPressed: onFilter,
                tooltip: 'Filter modifier groups',
                icon: const Icon(Icons.filter_list),
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (groups.isEmpty)
          const Padding(
            padding: AppSpacing.allXl,
            child: Text('No modifier groups match your search.'),
          )
        else
          ...groups.map(
            (ModifierGroup group) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ModifierGroupCard(
                key: Key('modifier-group-${group.id}'),
                group: group,
                isSelected: group.id == selectedGroupId,
                onTap: () => onSelected(group),
                onMore: () => onMore(group),
              ),
            ),
          ),
      ],
    );
  }
}
