import 'package:flutter/material.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/theme/app_colors.dart';
import 'cafe_configuration_navigation.dart';

class CafeConfigurationScaffold extends StatelessWidget {
  const CafeConfigurationScaffold({
    super.key,
    required this.child,
    required this.selected,
  });
  final Widget child;
  final CafeConfigurationDestination selected;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.contentBackground,
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        children: <Widget>[
          CafeConfigurationNavigation(selected: selected),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.menuModuleContentMaxWidth,
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.all(
                    constraints.maxWidth < 1440
                        ? AppSizes.menuModuleCompactContentPadding
                        : AppSizes.menuModuleStandardContentPadding,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
