import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../controllers/product_catalog_cubit.dart';
import '../../models/catalog_models.dart';
import '../../views/product_catalog_screen.dart' show CatalogProductImage;
import '../../widgets/catalog_formatters.dart';
import '../controllers/product_editor_cubit.dart';
import '../controllers/product_editor_state.dart';
import '../models/product_editor_draft.dart';

class ProductEditorScreen extends StatefulWidget {
  const ProductEditorScreen({super.key, this.productId});
  final int? productId;
  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  bool get _isCreate => widget.productId == null;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _isCreate
          ? context.read<ProductEditorCubit>().initializeCreate()
          : context.read<ProductEditorCubit>().loadForEdit(widget.productId!),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<ProductEditorCubit, ProductEditorState>(
        listenWhen: (_, current) =>
            current.status == ProductEditorStatus.success,
        listener: (context, state) async {
          final ProductDetail product = state.savedProduct!;
          await context.read<ProductCatalogCubit>().refresh();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isCreate
                    ? 'Product created successfully.'
                    : 'Product updated successfully.',
              ),
            ),
          );
          context.go('/menu-management/products/${product.id}');
        },
        child: BlocBuilder<ProductEditorCubit, ProductEditorState>(
          builder: (context, state) {
            final bool allowPop =
                !state.isDirty || state.status == ProductEditorStatus.success;
            return PopScope(
              canPop: allowPop,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _confirmLeave();
              },
              child: DesktopPageLayout(
                padding: EdgeInsets.zero,
                child: _body(state),
              ),
            );
          },
        ),
      );

  Widget _body(ProductEditorState state) {
    if (state.status == ProductEditorStatus.initial ||
        state.status == ProductEditorStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == ProductEditorStatus.failure &&
        state.formError != null &&
        state.productId != null &&
        state.draft.name.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(state.formError!),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: context.read<ProductEditorCubit>().retry,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final ProductEditorCubit cubit = context.read<ProductEditorCubit>();
    final ProductEditorDraft d = state.draft;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        96,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: _confirmLeave,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed:
                      state.status == ProductEditorStatus.submitting ||
                          state.isReadOnly
                      ? null
                      : cubit.submit,
                  icon: state.status == ProductEditorStatus.submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    state.status == ProductEditorStatus.submitting
                        ? 'Saving...'
                        : 'Save Product',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _isCreate ? 'Create Product' : 'Edit Product',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (state.isReadOnly) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                message:
                    'This Product is archived and can no longer be edited.',
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () =>
                    context.go('/menu-management/products/${widget.productId}'),
                child: const Text('View Product Detail'),
              ),
            ] else if (state.formError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _Banner(message: state.formError!),
            ],
            if (state.referenceErrors.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _Banner(
                message:
                    'Some reference data could not be loaded: ${state.referenceErrors.keys.join(', ')}.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Basic Information',
              child: Column(
                children: <Widget>[
                  _text(
                    'Default name',
                    d.name,
                    (v) => cubit.updateDraft(d.copyWith(name: v)),
                    error: state.fieldErrors['name'],
                    required: true,
                  ),
                  _text(
                    'Arabic name',
                    d.nameAr,
                    (v) => cubit.updateDraft(d.copyWith(nameAr: v)),
                    error: state.fieldErrors['nameAr'],
                  ),
                  _text(
                    'English name',
                    d.nameEn,
                    (v) => cubit.updateDraft(d.copyWith(nameEn: v)),
                    error: state.fieldErrors['nameEn'],
                  ),
                  _text(
                    'Default description',
                    d.description,
                    (v) => cubit.updateDraft(d.copyWith(description: v)),
                    error: state.fieldErrors['description'],
                    lines: 3,
                  ),
                  _text(
                    'Arabic description',
                    d.descriptionAr,
                    (v) => cubit.updateDraft(d.copyWith(descriptionAr: v)),
                    error: state.fieldErrors['descriptionAr'],
                    lines: 3,
                  ),
                  _text(
                    'English description',
                    d.descriptionEn,
                    (v) => cubit.updateDraft(d.copyWith(descriptionEn: v)),
                    error: state.fieldErrors['descriptionEn'],
                    lines: 3,
                  ),
                  _text(
                    'Image URL',
                    d.imageUrl,
                    (v) => cubit.updateDraft(d.copyWith(imageUrl: v)),
                    error: state.fieldErrors['imageUrl'],
                    keyboard: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      CatalogProductImage(
                        url: d.imageUrl.trim().isEmpty
                            ? null
                            : d.imageUrl.trim(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Image preview', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  _select<String>(
                    'Product type',
                    d.productType,
                    const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Standard'),
                      ),
                      DropdownMenuItem(
                        value: 'open_price',
                        child: Text('Open price'),
                      ),
                    ],
                    (v) => cubit.updateDraft(
                      d.copyWith(productType: v ?? 'standard'),
                    ),
                    state.fieldErrors['productType'],
                  ),
                  if (d.productType == 'open_price')
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        'The final price will be entered during sale in a future supported flow.',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Classification',
              child: Column(
                children: <Widget>[
                  _select<int>(
                    'Catalog category',
                    d.categoryId,
                    state.categories
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    (v) => cubit.updateDraft(
                      d.copyWith(categoryId: v, clearCategory: v == null),
                    ),
                    state.fieldErrors['categoryId'],
                    required: true,
                  ),
                  _select<int>(
                    'Reporting category',
                    d.reportingCategoryId,
                    state.reportingCategories
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    (v) => cubit.updateDraft(
                      d.copyWith(
                        reportingCategoryId: v,
                        clearReportingCategory: v == null,
                      ),
                    ),
                    state.fieldErrors['reportingCategoryId'],
                  ),
                  _select<int>(
                    'Kitchen station',
                    d.kitchenStationId,
                    state.kitchenStations
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    (v) => cubit.updateDraft(
                      d.copyWith(
                        kitchenStationId: v,
                        clearKitchenStation: v == null,
                      ),
                    ),
                    state.fieldErrors['kitchenStationId'],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Section(
              title: 'Operations',
              child: Column(
                children: <Widget>[
                  _text(
                    'Preparation time (minutes)',
                    d.preparationTimeMinutes,
                    (v) => cubit.updateDraft(
                      d.copyWith(preparationTimeMinutes: v),
                    ),
                    error: state.fieldErrors['preparationTimeMinutes'],
                    digits: true,
                  ),
                  Material(
                    color: AppColors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Stock tracked'),
                      value: d.isStockTracked,
                      onChanged: (v) =>
                          cubit.updateDraft(d.copyWith(isStockTracked: v)),
                    ),
                  ),
                  _text(
                    'Sort order',
                    d.sortOrder,
                    (v) => cubit.updateDraft(d.copyWith(sortOrder: v)),
                    error: state.fieldErrors['sortOrder'],
                    digits: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isCreate)
              _Section(
                title: 'Initial Default Variant',
                child: _variantFields(d, state, cubit),
              )
            else
              _Section(
                title: 'Current Default Variant',
                child: _variantSummary(state.currentDefaultVariant),
              ),
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: state.status == ProductEditorStatus.submitting
                    ? null
                    : cubit.submit,
                child: Text(
                  state.status == ProductEditorStatus.submitting
                      ? 'Saving...'
                      : 'Save Product',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _variantFields(
    ProductEditorDraft d,
    ProductEditorState state,
    ProductEditorCubit cubit,
  ) => Column(
    children: <Widget>[
      _text(
        'Variant name',
        d.variantName,
        (v) => cubit.updateDraft(d.copyWith(variantName: v)),
        error: state.fieldErrors['variants.0.name'],
        required: true,
      ),
      _text(
        'Arabic name',
        d.variantNameAr,
        (v) => cubit.updateDraft(d.copyWith(variantNameAr: v)),
        error: state.fieldErrors['variants.0.nameAr'],
      ),
      _text(
        'English name',
        d.variantNameEn,
        (v) => cubit.updateDraft(d.copyWith(variantNameEn: v)),
        error: state.fieldErrors['variants.0.nameEn'],
      ),
      _text(
        'Base price',
        d.variantBasePrice,
        (v) => cubit.updateDraft(d.copyWith(variantBasePrice: v)),
        error: state.fieldErrors['variants.0.basePrice'],
        price: true,
        required: d.productType == 'standard',
      ),
      _text(
        'Cost price',
        d.variantCostPrice,
        (v) => cubit.updateDraft(d.copyWith(variantCostPrice: v)),
        error: state.fieldErrors['variants.0.costPrice'],
        price: true,
      ),
      _text(
        'SKU',
        d.variantSku,
        (v) => cubit.updateDraft(d.copyWith(variantSku: v)),
        error: state.fieldErrors['variants.0.sku'],
      ),
      _text(
        'Barcode',
        d.variantBarcode,
        (v) => cubit.updateDraft(d.copyWith(variantBarcode: v)),
        error: state.fieldErrors['variants.0.barcode'],
      ),
    ],
  );
  Widget _variantSummary(ProductVariant? v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(v?.name ?? 'No default variant returned.'),
      if (v != null)
        Text('${catalogMoney(v.basePrice)} · SKU: ${v.sku ?? '—'}'),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Advanced Variant editing is managed separately from Product General information.',
      ),
      const SizedBox(height: AppSpacing.sm),
      OutlinedButton.icon(
        onPressed: widget.productId == null
            ? null
            : () => context.go(
                '/menu-management/products/${widget.productId}/variants',
              ),
        icon: const Icon(Icons.tune_outlined),
        label: const Text('Manage Variants'),
      ),
    ],
  );
  Widget _text(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    String? error,
    bool required = false,
    int lines = 1,
    bool digits = false,
    bool price = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      initialValue: value,
      maxLines: lines,
      keyboardType:
          keyboard ??
          (price
              ? const TextInputType.numberWithOptions(decimal: true)
              : digits
              ? TextInputType.number
              : TextInputType.text),
      inputFormatters: price
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ]
          : digits
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        errorText: error,
      ),
    ),
  );
  Widget _select<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
    String? error, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      hint: const Text('None'),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        errorText: error,
      ),
      items: items,
      onChanged: onChanged,
    ),
  );
  Future<void> _confirmLeave() async {
    final ProductEditorState state = context.read<ProductEditorCubit>().state;
    if (!state.isDirty) {
      if (mounted) context.pop();
      return;
    }
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Leave without saving?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.pop();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allLg,
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text(message),
  );
}
