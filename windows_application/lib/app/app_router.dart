import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/services/service_locator.dart';
import '../features/orders/controllers/orders_cubit.dart';
import '../features/orders/views/orders_screen.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/views/pos_screen.dart';
import '../features/pos/widgets/pos_cart_panel.dart';
import 'app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.pos,
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        final AppShell shell = AppShell(
          activeLabel: _activeLabelFor(state),
          rightPanel: _rightPanelFor(state),
          child: child,
        );

        return MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<PosCubit>(
              create: (_) => serviceLocator<PosCubit>()..loadInitialData(),
            ),
            BlocProvider<OrdersCubit>(
              create: (_) => serviceLocator<OrdersCubit>()..loadOrders(),
            ),
          ],
          child: shell,
        );
      },
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.pos,
          name: AppRouteNames.pos,
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: AppRoutes.orders,
          name: AppRouteNames.orders,
          builder: (context, state) => const OrdersScreen(),
        ),
      ],
    ),
  ],
);

Widget? _rightPanelFor(GoRouterState state) {
  return switch (state.matchedLocation) {
    AppRoutes.pos => const PosCartPanel(),
    _ => null,
  };
}

String _activeLabelFor(GoRouterState state) {
  return switch (state.matchedLocation) {
    AppRoutes.orders => 'Orders',
    _ => 'POS',
  };
}

abstract final class AppRoutes {
  static const String pos = '/';
  static const String orders = '/orders';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
  static const String orders = 'orders';
}
