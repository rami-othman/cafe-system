import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../pos/models/branch.dart';
import '../../menus/models/menu_filter.dart';
import '../../menus/models/menu_models.dart';
import '../../models/catalog_models.dart';
import '../configured_price_validation.dart';
import '../controllers/menu_pricing_cubit.dart';
import '../controllers/menu_pricing_state.dart';
import '../models/menu_price_adjustment_models.dart';
import '../models/menu_pricing_models.dart';

const _channels = <String>[
  'pos',
  'waiter_app',
  'kiosk',
  'qr_ordering',
  'delivery',
  'online_ordering',
];

class MenuPricingScreen extends StatefulWidget {
  const MenuPricingScreen({super.key});
  @override
  State<MenuPricingScreen> createState() => _MenuPricingScreenState();
}

class _MenuPricingScreenState extends State<MenuPricingScreen> {
  List<MenuRecord> _menus = const [];
  List<Branch> _branches = const [];
  List<CatalogCategory> _categories = const [];
  int? _menuId;
  int? _branchId;
  int? _categoryId;
  String _channel = 'pos';
  String _search = '';
  bool _contextsLoading = true;
  String? _contextsError;
  late VoidCallback _unregisterUnsavedNavigation;
  bool _registeredUnsavedNavigation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContexts());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredUnsavedNavigation) return;
    final navigation = UnsavedNavigationScope.maybeOf(context);
    if (navigation == null) return;
    _registeredUnsavedNavigation = true;
    _unregisterUnsavedNavigation = navigation.register(
      UnsavedNavigationGuard(
        isDirty: () => context.read<MenuPricingCubit>().state.hasUnsavedWork,
        confirmLeave: _confirmLeave,
      ),
    );
  }

  @override
  void dispose() {
    if (_registeredUnsavedNavigation) _unregisterUnsavedNavigation();
    super.dispose();
  }

  Future<void> _loadContexts() async {
    setState(() {
      _contextsLoading = true;
      _contextsError = null;
    });
    final repository = context.read<MenuPricingCubit>().repository;
    try {
      final values = await Future.wait<dynamic>([
        _allMenusFromRepository(),
        repository.listAssignmentBranches(),
        _allCategoriesFromRepository(),
      ]);
      if (!mounted) return;
      final menus = (values[0] as List<MenuRecord>)
          .where((m) => m.status != 'archived')
          .toList(growable: false);
      final branches = (values[1] as List<Branch>)
          .where((branch) => branch.isActive)
          .toList(growable: false);
      setState(() {
        _menus = menus;
        _branches = branches;
        _categories = values[2] as List<CatalogCategory>;
        _menuId = menus.isEmpty
            ? null
            : (_menuId != null && menus.any((m) => m.id == _menuId)
                  ? _menuId
                  : menus.first.id);
        _branchId = branches.isEmpty
            ? null
            : (_branchId != null && branches.any((b) => b.id == _branchId)
                  ? _branchId
                  : branches.first.id);
        _contextsLoading = false;
      });
      if (_menuId != null && _branchId != null) {
        _reload();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _contextsLoading = false;
          _contextsError = 'pricingContextsFailed';
        });
      }
    }
  }

  Future<List<MenuRecord>> _allMenusFromRepository() async {
    final repository = context.read<MenuPricingCubit>().repository;
    final result = <MenuRecord>[];
    var page = 1;
    while (true) {
      final response = await repository.listMenus(
        filter: const MenuFilter(status: 'all'),
        page: page,
        perPage: 100,
      );
      result.addAll(response.items);
      if (!response.meta.hasNextPage) return result;
      page++;
    }
  }

  Future<List<CatalogCategory>> _allCategoriesFromRepository() async {
    final repository = context.read<MenuPricingCubit>().repository;
    final result = <CatalogCategory>[];
    final response = await repository.listCategories(perPage: 100);
    // Existing category contract presently has no page argument. Retain its
    // complete active reference page rather than inventing a new request.
    result.addAll(response.items);
    return result;
  }

  Future<void> _reload({int page = 1}) async {
    if (_menuId == null || _branchId == null) return;
    await context.read<MenuPricingCubit>().load(
      menuId: _menuId!,
      branchId: _branchId!,
      channel: _channel,
      search: _search,
      categoryId: _categoryId,
      page: page,
    );
  }

  Future<void> _changeContext({
    int? menuId,
    int? branchId,
    String? channel,
  }) async {
    final nextMenu = menuId ?? _menuId;
    final nextBranch = branchId ?? _branchId;
    final nextChannel = channel ?? _channel;
    if (nextMenu == null || nextBranch == null) return;
    final cubit = context.read<MenuPricingCubit>();
    final next = MenuPricingContextKey(nextMenu, nextBranch, nextChannel);
    if (cubit.state.contextKey != null && cubit.state.contextKey != next) {
      if (cubit.state.blocksContextChange) {
        _showMessage(context.l10n.pricingApplyRecoveryRequired);
        return;
      }
      if (cubit.state.hasUnsavedWork && !await _confirmContextDiscard()) return;
      if (!mounted) return;
      setState(() {
        _menuId = nextMenu;
        _branchId = nextBranch;
        _channel = nextChannel;
        _categoryId = null;
        _search = '';
      });
      await cubit.discardAndLoad(
        menuId: nextMenu,
        branchId: nextBranch,
        channel: nextChannel,
      );
      return;
    }
    setState(() {
      _menuId = nextMenu;
      _branchId = nextBranch;
      _channel = nextChannel;
    });
    await _reload();
  }

  Future<bool> _confirmLeave() async {
    final state = context.read<MenuPricingCubit>().state;
    if (state.blocksContextChange) return false;
    return await _confirmContextDiscard();
  }

  Future<bool> _confirmContextDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(dialog.l10n.pricingDiscardTitle),
          content: Text(dialog.l10n.pricingDiscardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(dialog.l10n.pricingKeepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(dialog.l10n.pricingDiscard),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<MenuPricingCubit, MenuPricingState>(
        listenWhen: (previous, current) =>
            previous.savedAdjustmentId != current.savedAdjustmentId &&
            current.savedAdjustmentId != null,
        listener: (context, state) {
          if (state.hasSavedHandoff) {
            _showMessage(context.l10n.pricingSavedHandoff);
          }
        },
        builder: (context, state) => PopScope(
          canPop: !state.hasUnsavedWork,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final approved = await _confirmLeave();
            if (!mounted || !approved) return;
            Navigator.of(this.context).maybePop();
          },
          child: DesktopPageLayout(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 96),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.pricingTitle,
                      style: AppTextStyles.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.l10n.pricingSubtitle,
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _contextPanel(state),
                    if (_contextsLoading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_contextsError != null)
                      _retryNotice(
                        context.l10n.pricingContextsFailed,
                        _loadContexts,
                      ),
                    if (!_contextsLoading &&
                        _contextsError == null &&
                        (_menus.isEmpty || _branches.isEmpty))
                      _notice(context.l10n.pricingContextsEmpty),
                    if (state.status == MenuPricingStatus.forbidden)
                      _notice(context.l10n.pricingForbidden),
                    if (state.hasUnresolvedApply) _recoveryNotice(state),
                    if (state.error != null && !state.hasUnresolvedApply)
                      _notice(_error(state.error!)),
                    if (state.hasSavedHandoff) _savedHandoff(state),
                    if (state.overview != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _scope(state),
                      const SizedBox(height: AppSpacing.lg),
                      _actions(state),
                      const SizedBox(height: AppSpacing.lg),
                      _table(state),
                      const SizedBox(height: AppSpacing.lg),
                      _pagination(state),
                    ] else if (state.status == MenuPricingStatus.loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _contextPanel(MenuPricingState state) => Card(
    child: Padding(padding: AppSpacing.allLg, child: _contextBar(state)),
  );

  Widget _contextBar(MenuPricingState state) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 260.0;
      double fieldWidth(double requested) => math.min(requested, maxWidth);
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          _dropdown<int>(
            fieldWidth(230),
            _menuId,
            context.l10n.pricingMenu,
            _menus
                .map(
                  (m) => DropdownMenuItem(
                    value: m.id,
                    child: _dropdownText(m.name),
                  ),
                )
                .toList(),
            state.blocksContextChange
                ? null
                : (value) {
                    if (value != null) _changeContext(menuId: value);
                  },
          ),
          _dropdown<int>(
            fieldWidth(220),
            _branchId,
            context.l10n.pricingBranch,
            _branches
                .map(
                  (b) => DropdownMenuItem(
                    value: b.id,
                    child: _dropdownText(b.name),
                  ),
                )
                .toList(),
            state.blocksContextChange
                ? null
                : (value) {
                    if (value != null) _changeContext(branchId: value);
                  },
          ),
          _dropdown<String>(
            fieldWidth(180),
            _channel,
            context.l10n.pricingChannel,
            _channels
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: _dropdownText(_channelLabel(value)),
                  ),
                )
                .toList(),
            state.blocksContextChange
                ? null
                : (value) {
                    if (value != null) _changeContext(channel: value);
                  },
          ),
          _dropdown<int?>(
            fieldWidth(220),
            _categoryId,
            context.l10n.pricingCategory,
            [
              DropdownMenuItem<int?>(
                value: null,
                child: _dropdownText(context.l10n.pricingAllCategories),
              ),
              ..._categories.map(
                (c) => DropdownMenuItem<int?>(
                  value: c.id,
                  child: _dropdownText(
                    c.displayName(Localizations.localeOf(context)),
                  ),
                ),
              ),
            ],
            state.blocksContextChange
                ? null
                : (value) {
                    setState(() => _categoryId = value);
                    _reload();
                  },
          ),
          SizedBox(
            width: fieldWidth(260),
            child: TextField(
              enabled: !state.blocksContextChange,
              onSubmitted: (value) {
                _search = value;
                _reload();
              },
              decoration: InputDecoration(
                labelText: context.l10n.pricingSearch,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _dropdown<T>(
    double width,
    T? value,
    String label,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? changed,
  ) => SizedBox(
    width: width,
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: changed,
    ),
  );

  Widget _dropdownText(String value) => Text(
    value,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
  );

  Widget _scope(MenuPricingState state) => Container(
    padding: AppSpacing.allMd,
    decoration: const BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: AppRadius.card,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(end: AppSpacing.md, top: 1),
          child: Icon(Icons.info_outline, color: AppColors.secondary),
        ),
        Expanded(
          child: Text(
            context.l10n.pricingBulkScope(
              state.overview!.adjustableVariantCount,
              state.overview!.excludedVariantCount,
            ),
            style: AppTextStyles.bodyMedium,
          ),
        ),
      ],
    ),
  );

  Widget _table(MenuPricingState state) => Card(
    clipBehavior: Clip.antiAlias,
    child: Container(
      decoration: const BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
        borderRadius: AppRadius.card,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceAlt),
          columns: [
            DataColumn(label: Text(context.l10n.pricingProductVariant)),
            DataColumn(label: Text(context.l10n.pricingConfigured)),
            DataColumn(label: Text(context.l10n.pricingInherited)),
            DataColumn(label: Text(context.l10n.pricingPublished)),
            DataColumn(label: Text(context.l10n.pricingActions)),
          ],
          rows: state.overview!.items
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.localizedName(_arabic)} — ${item.localizedVariant(_arabic)}',
                          ),
                          Text(
                            item.sku ??
                                (item.hasVisiblePlacement
                                    ? ''
                                    : context.l10n.pricingHiddenPlacement),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      _price(
                        item.configuredEffectivePrice,
                        _source(item.configuredSource),
                      ),
                    ),
                    DataCell(
                      _price(
                        item.inheritedPrice,
                        _source(item.inheritedSource),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.publishedPrice == null
                            ? context.l10n.pricingNotPublished
                            : '${item.publishedPrice!.value} v${item.publishedVersion}',
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    DataCell(_rowActions(item, state)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ),
  );

  Widget _price(ExactDecimal price, String source) =>
      Text('${price.value} ($source)', textDirection: TextDirection.ltr);
  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';

  Widget _rowActions(MenuPricingItem item, MenuPricingState state) {
    if (!item.adjustable) return Text(context.l10n.pricingOpenPriceReadonly);
    final draft = state.drafts[item.variantId];
    final disabled = state.blocksContextChange;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: disabled ? null : () => _edit(item, draft),
          child: Text(
            draft?.action == ManualPriceAction.set
                ? context.l10n.pricingChangeDraft
                : context.l10n.pricingSetPrice,
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: disabled || !item.hasMenuOverride
              ? null
              : () => context.read<MenuPricingCubit>().setDraft(
                  ManualPriceDraft.reset(item.variantId),
                ),
          child: Text(
            item.hasMenuOverride
                ? context.l10n.pricingResetInherited
                : context.l10n.pricingAlreadyInherited,
          ),
        ),
        if (draft != null)
          IconButton(
            tooltip: context.l10n.pricingUndo,
            onPressed: disabled
                ? null
                : () => context.read<MenuPricingCubit>().undoDraft(
                    item.variantId,
                  ),
            icon: const Icon(Icons.undo),
          ),
      ],
    );
  }

  Future<void> _edit(MenuPricingItem item, ManualPriceDraft? draft) async {
    final controller = TextEditingController(
      text: draft?.price ?? item.configuredEffectivePrice.value,
    );
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => AlertDialog(
          title: Text(context.l10n.pricingSetFor(item.localizedName(_arabic))),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.ltr,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.pricingPositivePrice,
              errorText: error == null
                  ? null
                  : context.l10n.pricingPositivePriceError,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(context.l10n.pricingCancel),
            ),
            FilledButton(
              onPressed: () {
                final value = PricingDecimalInput.normalize(controller.text);
                final validation = PricingDecimalInput.money(value);
                if (validation != null) {
                  setDialog(() => error = validation);
                  return;
                }
                Navigator.pop(dialog, value);
              },
              child: Text(context.l10n.pricingSaveDraft),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      context.read<MenuPricingCubit>().setDraft(
        ManualPriceDraft.set(item.variantId, result),
      );
    }
  }

  Widget _actions(MenuPricingState state) => Container(
    padding: AppSpacing.allMd,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      borderRadius: AppRadius.card,
    ),
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        FilledButton.icon(
          onPressed: state.hasDrafts && !state.blocksContextChange
              ? () async {
                  if (await context.read<MenuPricingCubit>().previewManual() &&
                      mounted) {
                    _review(context.read<MenuPricingCubit>().state.review!);
                  }
                }
              : !state.hasDrafts && !state.blocksContextChange
              ? _bulk
              : null,
          icon: Icon(state.hasDrafts ? Icons.fact_check_outlined : Icons.tune),
          label: Text(
            state.hasDrafts
                ? context.l10n.pricingReviewChanges(state.drafts.length)
                : context.l10n.pricingAdjustAll,
          ),
        ),
        if (state.hasDrafts)
          OutlinedButton.icon(
            onPressed: state.blocksContextChange ? null : _bulkBlocked,
            icon: const Icon(Icons.tune),
            label: Text(context.l10n.pricingAdjustAll),
          ),
        if (state.review != null)
          OutlinedButton.icon(
            onPressed: state.isActionInFlight
                ? null
                : () => _review(state.review!),
            icon: const Icon(Icons.visibility_outlined),
            label: Text(context.l10n.pricingOpenReview),
          ),
      ],
    ),
  );

  Widget _pagination(MenuPricingState state) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.md,
    children: [
      if (state.overview!.page > 1)
        OutlinedButton(
          onPressed: state.blocksContextChange
              ? null
              : () => _reload(page: state.overview!.page - 1),
          child: Text(context.l10n.pricingPrevious),
        ),
      if (state.overview!.page * state.overview!.perPage <
          state.overview!.total)
        OutlinedButton(
          onPressed: state.blocksContextChange
              ? null
              : () => _reload(page: state.overview!.page + 1),
          child: Text(context.l10n.pricingNext),
        ),
    ],
  );

  void _bulkBlocked() => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(context.l10n.pricingPendingManualTitle),
      content: Text(context.l10n.pricingPendingManualMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(context.l10n.pricingKeepEditing),
        ),
        FilledButton(
          onPressed: () {
            context.read<MenuPricingCubit>().discardDrafts();
            Navigator.pop(dialog);
          },
          child: Text(context.l10n.pricingDiscard),
        ),
      ],
    ),
  );

  Future<void> _bulk() async {
    final amount = TextEditingController();
    final step = TextEditingController();
    var operation = 'percentage_increase';
    var rounding = 'no_rounding';
    var custom = false;
    var submitting = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) {
          final presets = _roundingPresets(
            context.read<MenuPricingCubit>().state.overview?.context.currency,
          );
          final useStep = rounding != 'no_rounding';
          final currency = context
              .read<MenuPricingCubit>()
              .state
              .overview
              ?.context
              .currency;
          final operationField = DropdownButtonFormField<String>(
            initialValue: operation,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.l10n.pricingOperation,
              prefixIcon: const Icon(Icons.tune),
            ),
            items: _operations
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: _dropdownText(_operation(v)),
                  ),
                )
                .toList(),
            onChanged: submitting
                ? null
                : (v) => setDialog(() => operation = v!),
          );
          final amountField = TextField(
            controller: amount,
            autofocus: true,
            textDirection: TextDirection.ltr,
            enabled: !submitting,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.pricingAmount,
              suffixText: operation.startsWith('percentage_') ? '%' : currency,
              errorText: error == 'amount'
                  ? context.l10n.pricingAmountError
                  : null,
            ),
          );
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  padding: AppSpacing.allXl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.pricingAdjustAll,
                              style: AppTextStyles.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.pricingCancel,
                            onPressed: submitting
                                ? null
                                : () => Navigator.pop(dialog),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: AppSpacing.allMd,
                        decoration: const BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppRadius.card,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsetsDirectional.only(
                                end: AppSpacing.md,
                                top: 1,
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: AppColors.secondary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                context.l10n.pricingBulkScope(
                                  context
                                      .read<MenuPricingCubit>()
                                      .state
                                      .overview!
                                      .adjustableVariantCount,
                                  context
                                      .read<MenuPricingCubit>()
                                      .state
                                      .overview!
                                      .excludedVariantCount,
                                ),
                                style: AppTextStyles.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 480) {
                            return Column(
                              children: [
                                operationField,
                                const SizedBox(height: AppSpacing.md),
                                amountField,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: operationField),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: amountField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Container(
                        padding: AppSpacing.allLg,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: AppRadius.card,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.pricingRoundingMode,
                              style: AppTextStyles.labelLarge,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              initialValue: rounding,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.l10n.pricingRoundingMode,
                                prefixIcon: const Icon(Icons.rounded_corner),
                              ),
                              items: _roundingModes
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: _dropdownText(_rounding(v)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: submitting
                                  ? null
                                  : (v) => setDialog(() => rounding = v!),
                            ),
                            if (useStep) ...[
                              const SizedBox(height: AppSpacing.md),
                              DropdownButtonFormField<String>(
                                initialValue: custom
                                    ? 'custom'
                                    : (presets.contains(step.text)
                                          ? step.text
                                          : presets.first),
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: context.l10n.pricingRoundingStep,
                                ),
                                items: [
                                  ...presets.map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: _dropdownText(p),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'custom',
                                    child: _dropdownText(
                                      context.l10n.pricingCustomStep,
                                    ),
                                  ),
                                ],
                                onChanged: submitting
                                    ? null
                                    : (v) => setDialog(() {
                                        custom = v == 'custom';
                                        if (!custom) step.text = v!;
                                      }),
                              ),
                            ],
                            if (useStep && custom) ...[
                              const SizedBox(height: AppSpacing.md),
                              TextField(
                                controller: step,
                                enabled: !submitting,
                                textDirection: TextDirection.ltr,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: context.l10n.pricingCustomStep,
                                  errorText: error == 'step'
                                      ? context.l10n.pricingPositivePriceError
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            TextButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.pop(dialog),
                              child: Text(context.l10n.pricingCancel),
                            ),
                            FilledButton.icon(
                              onPressed: submitting
                                  ? null
                                  : () async {
                                      final normalAmount =
                                          PricingDecimalInput.normalize(
                                            amount.text,
                                          );
                                      final normalStep =
                                          PricingDecimalInput.normalize(
                                            step.text.isEmpty
                                                ? presets.first
                                                : step.text,
                                          );
                                      final amountError =
                                          PricingDecimalInput.amount(
                                            normalAmount,
                                            percentageDecrease:
                                                operation ==
                                                'percentage_decrease',
                                          );
                                      final stepError = useStep
                                          ? PricingDecimalInput.roundingStep(
                                              normalStep,
                                            )
                                          : null;
                                      if (amountError != null ||
                                          stepError != null) {
                                        setDialog(
                                          () => error = amountError != null
                                              ? 'amount'
                                              : 'step',
                                        );
                                        return;
                                      }
                                      setDialog(() => submitting = true);
                                      final ok = await context
                                          .read<MenuPricingCubit>()
                                          .previewBulk(
                                            operation: operation,
                                            amount: normalAmount,
                                            roundingMode: rounding,
                                            roundingStep: useStep
                                                ? normalStep
                                                : null,
                                          );
                                      if (!dialog.mounted) return;
                                      if (!ok) {
                                        setDialog(() => submitting = false);
                                        return;
                                      }
                                      Navigator.pop(dialog);
                                      if (mounted) {
                                        _review(
                                          context
                                              .read<MenuPricingCubit>()
                                              .state
                                              .review!,
                                        );
                                      }
                                    },
                              icon: submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textInverse,
                                      ),
                                    )
                                  : const Icon(Icons.visibility_outlined),
                              label: Text(context.l10n.pricingPreview),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    amount.dispose();
    step.dispose();
  }

  void _review(MenuPriceAdjustment review) {
    final cubit = context.read<MenuPricingCubit>();
    showDialog<void>(
      context: context,
      builder: (dialog) {
        var acknowledged = false;
        var reviewed = false;
        return BlocProvider.value(
          value: cubit,
          child: StatefulBuilder(
            builder: (dialog, setDialog) =>
                BlocBuilder<MenuPricingCubit, MenuPricingState>(
                  builder: (context, state) => AlertDialog(
                    title: Text(context.l10n.pricingReviewTitle),
                    content: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 960,
                        maxHeight: 640,
                      ),
                      child: SizedBox(
                        width: 960,
                        height: _reviewDialogHeight(context),
                        child: ListView(
                          padding: AppSpacing.allLg,
                          children: [
                            _reviewNotice(
                              Icons.info_outline,
                              review.operation == 'manual_changes'
                                  ? context.l10n.pricingManualReview
                                  : context.l10n.pricingBulkWarning,
                            ),
                            if (review.operation != 'manual_changes')
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                ),
                                child: _reviewNotice(
                                  Icons.account_tree_outlined,
                                  context.l10n.pricingInheritanceWarning,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.lg),
                            _summary(review),
                            if (state.reviewApplyRejected)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.lg,
                                ),
                                child: _reviewNotice(
                                  Icons.error_outline,
                                  _error(state.error ?? 'pricingPreviewStale'),
                                  background: AppColors.refundWarningBackground,
                                  border: AppColors.refundWarningBorder,
                                  iconColor: AppColors.danger,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.lg),
                            for (final item in review.items) ...[
                              _reviewDetailCard(item, review),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            Container(
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: AppRadius.card,
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      value: reviewed,
                                      onChanged: state.isActionInFlight
                                          ? null
                                          : (value) => setDialog(
                                              () => reviewed = value == true,
                                            ),
                                      title: Text(
                                        context.l10n.pricingReviewedResults,
                                      ),
                                    ),
                                    if (review.oppositeDirectionCount > 0)
                                      CheckboxListTile(
                                        value: acknowledged,
                                        onChanged: state.isActionInFlight
                                            ? null
                                            : (value) => setDialog(
                                                () => acknowledged =
                                                    value == true,
                                              ),
                                        title: Text(
                                          context.l10n
                                              .pricingOppositeAcknowledgement(
                                                review.oppositeDirectionCount,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: Text(context.l10n.pricingClose),
                      ),
                      FilledButton.icon(
                        onPressed:
                            state.isActionInFlight ||
                                state.review?.id != review.id ||
                                state.review?.fingerprint !=
                                    review.fingerprint ||
                                !state.isReviewApplyCandidate ||
                                !reviewed ||
                                (review.oppositeDirectionCount > 0 &&
                                    !acknowledged) ||
                                !review.isApplyCandidate
                            ? null
                            : () async {
                                final ok = await context
                                    .read<MenuPricingCubit>()
                                    .apply(
                                      adjustmentId: review.id,
                                      fingerprint: review.fingerprint,
                                      acknowledgeOppositeDirection:
                                          acknowledged,
                                    );
                                if (ok && dialog.mounted) Navigator.pop(dialog);
                              },
                        icon: state.isActionInFlight
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textInverse,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(context.l10n.pricingApply),
                      ),
                    ],
                  ),
                ),
          ),
        );
      },
    );
  }

  Widget _reviewNotice(
    IconData icon,
    String message, {
    Color background = AppColors.primarySoft,
    Color border = AppColors.border,
    Color iconColor = AppColors.secondary,
  }) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    decoration: BoxDecoration(
      color: background,
      border: Border.all(color: border),
      borderRadius: AppRadius.card,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.md, top: 1),
          child: Icon(icon, color: iconColor),
        ),
        Expanded(child: Text(message, style: AppTextStyles.bodySmall)),
      ],
    ),
  );

  Widget _summary(MenuPriceAdjustment review) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    decoration: const BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: AppRadius.card,
    ),
    child: Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _count(
          context.l10n.pricingInheritedCount,
          review.summary['inheritedVariantCount'],
        ),
        _count(
          context.l10n.pricingExistingOverrideCount,
          review.summary['menuOverrideVariantCount'],
        ),
        _count(
          context.l10n.pricingCreatedCount,
          review.summary['overridesToCreateCount'],
        ),
        _count(
          context.l10n.pricingUpdatedCount,
          review.summary['overridesToUpdateCount'],
        ),
        _count(
          context.l10n.pricingRemovedCount,
          review.summary['overridesToRemoveCount'],
        ),
        _count(
          context.l10n.pricingIncreaseCount,
          review.summary['finalIncreaseCount'],
        ),
        _count(
          context.l10n.pricingDecreaseCount,
          review.summary['finalDecreaseCount'],
        ),
        _count(
          context.l10n.pricingUnchangedCount,
          review.summary['unchangedPriceCount'],
        ),
        _count(
          context.l10n.pricingExcludedCount,
          review.summary['excludedVariantCount'],
        ),
      ],
    ),
  );
  double _reviewDialogHeight(BuildContext context) =>
      math.min(640, math.max(360, MediaQuery.sizeOf(context).height - 48));
  Widget _count(String label, Object? value) => Container(
    constraints: const BoxConstraints(minWidth: 150),
    padding: AppSpacing.allSm,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.control,
    ),
    child: Text('$label: ${value ?? 0}', style: AppTextStyles.labelMedium),
  );

  Widget _reviewDetailCard(
    MenuPriceAdjustmentItem item,
    MenuPriceAdjustment review,
  ) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      borderRadius: AppRadius.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_itemName(item), style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(_action(item.action), style: AppTextStyles.labelMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _reviewMetric(
              context.l10n.pricingOriginal,
              '${item.originalEffectivePrice.value} (${_source(item.originalSource)})',
            ),
            _reviewMetric(
              context.l10n.pricingRaw,
              item.rawCalculatedPrice?.value ?? '—',
            ),
            _reviewMetric(
              context.l10n.pricingRounding,
              '${_rounding(review.roundingMode)} ${review.roundingStep ?? ''}'
                  .trim(),
            ),
            _reviewMetric(
              context.l10n.pricingFinal,
              '${item.finalNewPrice.value} (${_source(item.finalSource)})',
            ),
            _reviewMetric(
              context.l10n.pricingDifference,
              '${item.difference.value} · ${_movement(item.finalMovement)}${item.oppositeDirection ? ' · ${context.l10n.pricingOpposite}' : ''}',
            ),
            _reviewMetric(
              context.l10n.pricingConfiguration,
              _effect(item.configurationEffect),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _reviewMetric(String label, String value) => Container(
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
    padding: AppSpacing.allSm,
    decoration: const BoxDecoration(
      color: AppColors.background,
      borderRadius: AppRadius.control,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    ),
  );

  String _itemName(MenuPriceAdjustmentItem item) =>
      _arabic && item.productNameAr.isNotEmpty
      ? '${item.productNameAr} — ${item.variantNameAr}'
      : item.productNameEn.isNotEmpty
      ? '${item.productNameEn} — ${item.variantNameEn}'
      : '${item.productName} — ${item.variantName}';

  Widget _recoveryNotice(MenuPricingState state) => Container(
    padding: AppSpacing.allMd,
    color: AppColors.primarySoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.pricingApplyUncertain),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: state.isRecovering
              ? null
              : () => context.read<MenuPricingCubit>().recover(),
          child: Text(context.l10n.pricingRecover),
        ),
      ],
    ),
  );
  Widget _savedHandoff(MenuPricingState state) => Container(
    padding: AppSpacing.allMd,
    color: AppColors.primarySoft,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.pricingSavedHandoff),
        if (state.overviewRefreshFailed)
          Text(context.l10n.pricingOverviewRefreshFailed),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.guardedGo(
            Uri(
              path: '/menu-management/review',
              queryParameters: {'branchId': '$_branchId', 'channel': _channel},
            ).toString(),
          ),
          child: Text(context.l10n.pricingReviewPublish),
        ),
      ],
    ),
  );
  Widget _notice(String message) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Container(
      padding: AppSpacing.allMd,
      color: AppColors.primarySoft,
      child: Text(message),
    ),
  );
  Widget _retryNotice(String message, VoidCallback retry) => Container(
    padding: AppSpacing.allMd,
    color: AppColors.primarySoft,
    child: Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: retry, child: Text(context.l10n.pricingRetry)),
      ],
    ),
  );
  void _showMessage(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  String _error(String code) => switch (code) {
    'pricingForbidden' => context.l10n.pricingForbidden,
    'pricingPreviewStale' => context.l10n.pricingPreviewStale,
    'pricingPreviewExpired' => context.l10n.pricingPreviewExpired,
    'pricingAcknowledgementRequired' =>
      context.l10n.pricingAcknowledgementRequired,
    'pricingApplyUncertain' => context.l10n.pricingApplyUncertain,
    'pricingOverviewRefreshFailed' => context.l10n.pricingOverviewRefreshFailed,
    _ => context.l10n.pricingFailed,
  };
  String _channelLabel(String value) => switch (value) {
    'pos' => context.l10n.pricingChannelPos,
    'waiter_app' => context.l10n.pricingChannelWaiter,
    'kiosk' => context.l10n.pricingChannelKiosk,
    'qr_ordering' => context.l10n.pricingChannelQr,
    'delivery' => context.l10n.pricingChannelDelivery,
    _ => context.l10n.pricingChannelOnline,
  };
  String _source(String value) => switch (value) {
    'menu' => context.l10n.pricingSourceMenu,
    'branch_channel' => context.l10n.pricingSourceBranchChannel,
    'branch' => context.l10n.pricingSourceBranch,
    'channel' => context.l10n.pricingSourceChannel,
    _ => context.l10n.pricingSourceBase,
  };
  String _action(String value) => value == 'reset'
      ? context.l10n.pricingActionReset
      : context.l10n.pricingActionSet;
  String _movement(String value) => value == 'increase'
      ? context.l10n.pricingMovementIncrease
      : value == 'decrease'
      ? context.l10n.pricingMovementDecrease
      : context.l10n.pricingMovementUnchanged;
  String _effect(String value) => switch (value) {
    'create_override' => context.l10n.pricingEffectCreate,
    'update_override' => context.l10n.pricingEffectUpdate,
    'remove_override' => context.l10n.pricingEffectRemove,
    _ => context.l10n.pricingEffectUnchanged,
  };
  String _operation(String value) => switch (value) {
    'percentage_increase' => context.l10n.pricingPercentIncrease,
    'fixed_increase' => context.l10n.pricingFixedIncrease,
    'percentage_decrease' => context.l10n.pricingPercentDecrease,
    _ => context.l10n.pricingFixedDecrease,
  };
  String _rounding(String value) => switch (value) {
    'round_up' => context.l10n.pricingRoundUp,
    'round_down' => context.l10n.pricingRoundDown,
    _ => context.l10n.pricingNoRounding,
  };
}

const _operations = <String>[
  'percentage_increase',
  'fixed_increase',
  'percentage_decrease',
  'fixed_decrease',
];
const _roundingModes = <String>['no_rounding', 'round_up', 'round_down'];
List<String> _roundingPresets(String? currency) =>
    switch (currency?.toUpperCase()) {
      'SYP' => const ['100', '500', '1000'],
      'USD' || 'EUR' => const ['0.05', '0.10', '0.50', '1.00'],
      _ => const ['1.00'],
    };
