import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/customer_management_route_locations.dart';
import 'customer_management_module_tabs.dart';
import 'customer_management_visual_tokens.dart';

class CustomerManagementScaffold extends StatelessWidget {
  const CustomerManagementScaffold({
    super.key,
    required this.groupsSelected,
    required this.child,
  });

  final bool groupsSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CustomerManagementVisualTokens.pageBackground,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double horizontalPadding = constraints.maxWidth < 640 ? 16 : 24;
          return Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPadding,
              16,
              horizontalPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth:
                        CustomerManagementVisualTokens.moduleContentMaxWidth,
                  ),
                  child: CustomerManagementModuleTabs(
                    groupsSelected: groupsSelected,
                    onSelectionChanged: (bool groups) => context.go(
                      groups
                          ? CustomerManagementRouteLocations.groups
                          : CustomerManagementRouteLocations.customers,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: ConstrainedBox(
                      key: const ValueKey<String>(
                        'customer-management-scaffold-content',
                      ),
                      constraints: const BoxConstraints(
                        maxWidth: CustomerManagementVisualTokens
                            .moduleContentMaxWidth,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
