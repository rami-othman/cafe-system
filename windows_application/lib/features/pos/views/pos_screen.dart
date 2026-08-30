import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../app/localization/localization_extensions.dart';
import '../../../shared/layouts/desktop_page_layout.dart';
import '../controllers/pos_cubit.dart';
import '../controllers/pos_state.dart';
import '../controllers/pos_menu_sync_cubit.dart';
import '../controllers/pos_menu_sync_state.dart';
import '../models/backend_product_detail.dart';
import '../models/order_receipt.dart';
import '../models/pos_product.dart';
import '../models/pos_menu_runtime_models.dart';
import '../models/pos_published_menu_presenter.dart';
import '../models/product_detail_load_result.dart';
import '../models/product_customization.dart';
import '../widgets/product_customization_dialog.dart';
import '../widgets/pos_product_area.dart';
import '../widgets/receipt_preview_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  bool _isReceiptDialogOpen = false;
  bool _isCustomizationDialogOpen = false;
  int? _syncedBranchId;
  int? _selectedMenuId;
  int? _selectedSectionId;
  Timer? _reconnectRetryTimer;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMenuWhenReady());
  }

  void _syncMenuWhenReady() {
    if (!mounted) return;
    final PosState state = context.read<PosCubit>().state;
    if (!state.isBackendMode) return;
    if (!state.isLoading && _syncedBranchId != state.branchId) {
      _syncedBranchId = state.branchId;
      context.read<PosMenuSyncCubit>().sync(
        state.branchId,
        hasActiveCart: state.hasCartItems || state.currentOrderId != null,
      );
    }
  }

  void _scheduleBoundedReconnect(PosMenuSyncState state) {
    if (!mounted || _reconnectRetryTimer != null || _reconnectAttempts >= 3) {
      return;
    }
    final Duration delay = switch (_reconnectAttempts++) {
      0 => const Duration(seconds: 10),
      1 => const Duration(seconds: 30),
      _ => const Duration(seconds: 90),
    };
    _reconnectRetryTimer = Timer(delay, () {
      _reconnectRetryTimer = null;
      if (!mounted || state.branchId == null) return;
      final PosState pos = context.read<PosCubit>().state;
      unawaited(
        context.read<PosMenuSyncCubit>().sync(
          state.branchId!,
          hasActiveCart: pos.hasCartItems || pos.currentOrderId != null,
        ),
      );
    });
  }

  @override
  void dispose() {
    _reconnectRetryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: <BlocListenerBase<dynamic, dynamic>>[
        BlocListener<PosCubit, PosState>(
          listenWhen: (PosState previous, PosState current) =>
              previous.isLoading != current.isLoading ||
              previous.branchId != current.branchId,
          listener: (_, PosState state) {
            if (state.isLoading || !state.isBackendMode) _syncedBranchId = null;
            if (_syncedBranchId != state.branchId) {
              _selectedMenuId = null;
              _selectedSectionId = null;
            }
            _syncMenuWhenReady();
          },
        ),
        BlocListener<PosCubit, PosState>(
          listenWhen: (PosState previous, PosState current) =>
              (previous.hasCartItems || previous.currentOrderId != null) &&
              !current.hasCartItems &&
              current.currentOrderId == null,
          listener: (_, PosState state) => context
              .read<PosMenuSyncCubit>()
              .activatePendingIfSafe(hasActiveCart: state.hasCartItems),
        ),
        BlocListener<PosMenuSyncCubit, PosMenuSyncState>(
          listenWhen: (PosMenuSyncState previous, PosMenuSyncState current) =>
              previous.isBackendReachable != current.isBackendReachable,
          listener: (_, PosMenuSyncState state) => context
              .read<PosCubit>()
              .setBackendReachability(state.isBackendReachable),
        ),
        BlocListener<PosMenuSyncCubit, PosMenuSyncState>(
          listenWhen: (PosMenuSyncState previous, PosMenuSyncState current) =>
              previous.status != current.status,
          listener: (_, PosMenuSyncState state) {
            context.read<PosCubit>().setBackendReachability(
              state.isBackendReachable,
            );
            if (state.isBackendReachable) {
              _reconnectAttempts = 0;
              _reconnectRetryTimer?.cancel();
              _reconnectRetryTimer = null;
            } else if (state.status == PosMenuSyncStatus.offlineUsingCache ||
                state.status == PosMenuSyncStatus.noCacheOffline) {
              _scheduleBoundedReconnect(state);
            }
          },
        ),
        BlocListener<PosCubit, PosState>(
          listenWhen: (PosState previous, PosState current) {
            return (previous.lastReceipt != current.lastReceipt &&
                    current.lastReceipt != null) ||
                previous.apiErrorMessage != current.apiErrorMessage ||
                previous.cartMutationError != current.cartMutationError ||
                previous.paymentErrorMessage != current.paymentErrorMessage ||
                previous.receiptErrorMessage != current.receiptErrorMessage ||
                previous.uncertainPaymentMessage !=
                    current.uncertainPaymentMessage;
          },
          listener: (BuildContext context, PosState state) {
            final String? errorMessage =
                state.cartMutationError ??
                state.paymentErrorMessage ??
                state.apiErrorMessage;
            if (errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _localizedPosMessage(context, errorMessage) ??
                        (state.requiresMenuRefresh
                            ? context.l10n.posMenuRefreshRequired
                            : errorMessage),
                  ),
                ),
              );
            }

            if (state.receiptErrorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.receiptErrorMessage!),
                  action: SnackBarAction(
                    label: 'Retry Receipt',
                    onPressed: () =>
                        context.read<PosCubit>().retryPendingReceipt(),
                  ),
                ),
              );
            }

            if (state.uncertainPaymentMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.uncertainPaymentMessage!),
                  action: SnackBarAction(
                    label: 'Check Payment Status',
                    onPressed: () =>
                        context.read<PosCubit>().checkUncertainPaymentStatus(),
                  ),
                ),
              );
            }

            if (state.lastReceipt != null && !_isReceiptDialogOpen) {
              final OrderReceipt receipt = state.lastReceipt!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _isReceiptDialogOpen) {
                  return;
                }
                unawaited(_showReceiptDialog(context, receipt));
              });
            }
          },
        ),
      ],
      child: BlocBuilder<PosCubit, PosState>(
        builder: (BuildContext context, PosState state) =>
            BlocBuilder<PosMenuSyncCubit, PosMenuSyncState>(
              builder: (BuildContext context, PosMenuSyncState menuState) {
                final PosCubit cubit = context.read<PosCubit>();
                final _MenuDisplay display = _displayFor(
                  context,
                  state,
                  menuState,
                );

                return DesktopPageLayout(
                  child: Column(
                    children: <Widget>[
                      _MenuSyncStatusBar(state: menuState),
                      Expanded(
                        child: PosProductArea(
                          products: display.products,
                          menus: display.menus,
                          selectedMenuId: _selectedMenuId,
                          sections: display.sections,
                          selectedSectionId: _selectedSectionId,
                          searchQuery: state.searchQuery,
                          isLoading:
                              state.isLoading ||
                              menuState.status ==
                                      PosMenuSyncStatus
                                          .syncingWithUsableCache &&
                                  menuState.activeMenu == null,
                          emptyMessage: display.emptyMessage,
                          onSearchChanged: cubit.updateSearchQuery,
                          onMenuSelected: _selectMenu,
                          onSectionSelected: _selectSection,
                          legacyCategories: state.isBackendMode
                              ? const <String>[]
                              : state.categories,
                          selectedLegacyCategory: state.selectedCategory,
                          onLegacyCategorySelected: state.isBackendMode
                              ? null
                              : cubit.selectCategory,
                          onProductTap: state.isCartMutationInProgress
                              ? (_) {}
                              : (PosProduct product) =>
                                    _showCustomizationDialog(
                                      context,
                                      cubit,
                                      product,
                                    ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    );
  }

  _MenuDisplay _displayFor(
    BuildContext context,
    PosState pos,
    PosMenuSyncState sync,
  ) {
    // The in-memory demonstration repository is deliberately kept outside the
    // published-menu runtime path. It has no backend publication to sync and
    // must not create an endless network loader in shell/widget tests.
    if (!pos.isBackendMode) {
      return _MenuDisplay(
        products: pos.filteredProducts,
        emptyMessage: pos.filteredProducts.isEmpty
            ? context.l10n.posNoAvailableItems
            : null,
      );
    }
    final PosPublishedRuntimeMenu? runtime = sync.activeMenu;
    if (runtime == null) {
      return _MenuDisplay(
        emptyMessage: switch (sync.status) {
          PosMenuSyncStatus.noPublishedMenu => context.l10n.posNoPublishedMenu,
          PosMenuSyncStatus.noCacheOffline => context.l10n.posNoSavedMenu,
          PosMenuSyncStatus.fatalSyncError => context.l10n.posUnableToLoadMenu,
          _ => null,
        },
      );
    }
    final PosPublishedMenuPresenter presenter = PosPublishedMenuPresenter(
      runtime,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final List<PosStaticMenu> menus = presenter.menus;
    if (menus.isEmpty) {
      return _MenuDisplay(emptyMessage: context.l10n.posNoAvailableMenu);
    }
    final PosStaticMenu menu = menus.firstWhere(
      (PosStaticMenu item) => item.id == _selectedMenuId,
      orElse: () => menus.first,
    );
    _selectedMenuId = menu.id;
    final List<PosStaticSection> sections = menu.sections;
    if (sections.isEmpty) {
      return _MenuDisplay(
        menus: menus,
        emptyMessage: context.l10n.posNoAvailableItems,
      );
    }
    final PosStaticSection section = sections.firstWhere(
      (PosStaticSection item) => item.id == _selectedSectionId,
      orElse: () => sections.first,
    );
    _selectedSectionId = section.id;
    final List<PosProduct> menuProducts = presenter.productsForMenu(menu);
    final String search = context
        .read<PosCubit>()
        .state
        .searchQuery
        .trim()
        .toLowerCase();
    final List<PosProduct> products = search.isEmpty
        ? presenter.productsForSection(section)
        : menuProducts
              .where(
                (PosProduct item) => item.name.toLowerCase().contains(search),
              )
              .toList(growable: false);
    return _MenuDisplay(
      menus: menus,
      sections: sections,
      products: products,
      emptyMessage: products.isEmpty ? context.l10n.posNoAvailableItems : null,
    );
  }

  void _selectMenu(int menuId) => setState(() {
    _selectedMenuId = menuId;
    _selectedSectionId = null;
  });

  void _selectSection(int sectionId) =>
      setState(() => _selectedSectionId = sectionId);

  Future<void> _showCustomizationDialog(
    BuildContext context,
    PosCubit cubit,
    PosProduct product,
  ) async {
    if (!product.isAvailable) {
      return;
    }

    if (product.isPublishedRuntime) {
      await _openCustomizationDialog(context, cubit, product);
      return;
    }
    final ProductDetailLoadResult result = await cubit.loadProductDetail(
      product,
    );

    if (!context.mounted) {
      return;
    }

    switch (result) {
      case ProductDetailLoadStale():
        return;
      case ProductDetailLoadFailed(:final String message):
        await _showProductDetailFailure(context, cubit, product, message);
        return;
      case ProductDetailNotRequired():
        await _openCustomizationDialog(context, cubit, product);
        return;
      case ProductDetailLoaded(:final detail):
        await _openCustomizationDialog(
          context,
          cubit,
          product,
          productDetail: detail,
        );
        return;
    }
  }

  Future<void> _openCustomizationDialog(
    BuildContext context,
    PosCubit cubit,
    PosProduct product, {
    BackendProductDetail? productDetail,
  }) async {
    if (!context.mounted || _isCustomizationDialogOpen) {
      return;
    }
    _isCustomizationDialogOpen = true;

    try {
      await showGeneralDialog<ProductCustomization>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Close customization dialog',
        barrierColor: AppColors.black.withValues(alpha: 0.4),
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder:
            (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) {
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ProductCustomizationDialog(
                  product: product,
                  productDetail: productDetail,
                  onSubmit: cubit.addCustomizedProductToCart,
                ),
              );
            },
      );
    } finally {
      _isCustomizationDialogOpen = false;
    }
  }

  Future<void> _showProductDetailFailure(
    BuildContext context,
    PosCubit cubit,
    PosProduct product,
    String message,
  ) async {
    final bool? retry = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Product options unavailable'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );

    if (retry == true && context.mounted) {
      await _showCustomizationDialog(context, cubit, product);
    }
  }

  Future<void> _showReceiptDialog(
    BuildContext context,
    OrderReceipt receipt,
  ) async {
    if (_isReceiptDialogOpen || !context.mounted) {
      return;
    }
    _isReceiptDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.black.withValues(alpha: 0.42),
      builder: (BuildContext context) {
        return ReceiptPreviewDialog(receipt: receipt);
      },
    );

    _isReceiptDialogOpen = false;
    if (!context.mounted) {
      return;
    }

    final PosCubit cubit = context.read<PosCubit>();
    cubit.clearLastReceipt(receipt);
    final OrderReceipt? nextReceipt = cubit.state.lastReceipt;
    if (nextReceipt != null && nextReceipt != receipt) {
      unawaited(_showReceiptDialog(context, nextReceipt));
    }
  }

  String? _localizedPosMessage(BuildContext context, String message) {
    return switch (message) {
      PosCubit.connectionRequiredMessage =>
        context.l10n.posConnectionRequiredToCompleteOrder,
      PosCubit.menuChangedReviewMessage =>
        context.l10n.posMenuChangedReviewOrder,
      _ => null,
    };
  }
}

class _MenuDisplay {
  const _MenuDisplay({
    this.menus = const <PosStaticMenu>[],
    this.sections = const <PosStaticSection>[],
    this.products = const <PosProduct>[],
    this.emptyMessage,
  });

  final List<PosStaticMenu> menus;
  final List<PosStaticSection> sections;
  final List<PosProduct> products;
  final String? emptyMessage;
}

class _MenuSyncStatusBar extends StatelessWidget {
  const _MenuSyncStatusBar({required this.state});

  final PosMenuSyncState state;

  @override
  Widget build(BuildContext context) {
    final String? label = switch (state.status) {
      PosMenuSyncStatus.offlineUsingCache =>
        context.l10n.posOfflineUsingSavedMenu,
      PosMenuSyncStatus.syncErrorUsingCache =>
        context.l10n.posSyncErrorUsingSavedMenu,
      PosMenuSyncStatus.pendingVersion => context.l10n.posMenuUpdateReady,
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();
    final String? lastSynced = state.lastSyncedAt == null
        ? null
        : context.l10n.posLastSynced(
            MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(state.lastSyncedAt!.toLocal()),
            ),
          );
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.13),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        lastSynced == null ? label : '$label · $lastSynced',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
