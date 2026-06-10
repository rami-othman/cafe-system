import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/services/service_locator.dart';
import '../features/pos/controllers/pos_cubit.dart';
import '../features/pos/repositories/pos_repository.dart';
import '../features/pos/views/pos_screen.dart';
import '../features/pos/widgets/pos_cart_panel.dart';
import 'app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.pos,
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        if (state.matchedLocation == AppRoutes.pos) {
          return BlocProvider<PosCubit>(
            create: (_) =>
                PosCubit(repository: serviceLocator<PosRepository>())
                  ..loadInitialData(),
            child: AppShell(rightPanel: _rightPanelFor(state), child: child),
          );
        }

        return AppShell(rightPanel: _rightPanelFor(state), child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.pos,
          name: AppRouteNames.pos,
          builder: (context, state) => const PosScreen(),
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

abstract final class AppRoutes {
  static const String pos = '/';
}

abstract final class AppRouteNames {
  static const String pos = 'pos';
}
