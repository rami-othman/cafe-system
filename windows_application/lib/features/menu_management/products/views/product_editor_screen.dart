import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/menu_management_route_locations.dart';
import '../../../../app/localization/localization_extensions.dart';
import '../../../../core/navigation/unsaved_navigation_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../controllers/product_catalog_cubit.dart';
import '../../models/catalog_models.dart';
import '../../widgets/catalog_formatters.dart';
import '../../widgets/menu_content_components.dart';
import '../../widgets/menu_page_header.dart';
import '../../widgets/sticky_form_actions.dart';
import '../../pricing/configured_price_validation.dart';
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
  String? _localImagePath;
  late VoidCallback _unregisterUnsavedNavigation;
  bool _registeredUnsavedNavigation = false;

  bool get _isCreate => widget.productId == null;

  String get _returnLocation => _isCreate
      ? '/menu-management/products'
      : MenuManagementRouteLocations.productWorkspace(widget.productId!);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registeredUnsavedNavigation) return;
    final UnsavedNavigationController? navigation =
        UnsavedNavigationScope.maybeOf(context);
    if (navigation == null) return;
    _registeredUnsavedNavigation = true;
    _unregisterUnsavedNavigation = navigation.register(
      UnsavedNavigationGuard(
        isDirty: () => context.read<ProductEditorCubit>().state.isDirty,
        confirmLeave: _mayLeave,
      ),
    );
  }

  @override
  void dispose() {
    if (_registeredUnsavedNavigation) _unregisterUnsavedNavigation();
    super.dispose();
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
                    ? context.l10n.productEditorCreated
                    : context.l10n.productEditorUpdated,
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
                if (!didPop) _leaveToReturnLocation();
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
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    final ProductEditorCubit cubit = context.read<ProductEditorCubit>();
    final ProductEditorDraft draft = state.draft;
    final l10n = context.maybeL10n;
    final List<String> validation = <String>[
      if (state.formError != null) state.formError!,
      ...state.fieldErrors.values.take(1),
    ];
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextButton.icon(
                      onPressed: _leaveToReturnLocation,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.l10n.commonBack),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MenuPageHeader(
                      title: _isCreate
                          ? l10n?.productUxCreateProduct ?? 'Create Product'
                          : l10n?.productUxEditProduct ?? 'Edit Product',
                      subtitle: _isCreate
                          ? context.l10n.productEditorCreateHelp
                          : context.l10n.productEditorEditHelp,
                    ),
                    if (state.isReadOnly) ...<Widget>[
                      const SizedBox(height: AppSpacing.lg),
                      _Notice(
                        message: context.l10n.productEditorArchivedReadOnly,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(
                        onPressed: () => context.guardedGo(
                          '/menu-management/products/${widget.productId}',
                        ),
                        child: Text(context.l10n.productEditorViewWorkspace),
                      ),
                    ] else ...<Widget>[
                      if (state.referenceErrors.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        _Notice(
                          message:
                              'Some catalog setup data could not be loaded: ${state.referenceErrors.keys.join(', ')}.',
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      ContentSection(
                        title: l10n?.productUxGeneral ?? 'General',
                        description: context.l10n.productEditorWhatIsProduct,
                        child: _FormGrid(
                          children: <Widget>[
                            _text(
                              context.l10n.productEditorDefaultName,
                              draft.name,
                              (value) => cubit.updateDraft(
                                draft.copyWith(name: value),
                              ),
                              error: state.fieldErrors['name'],
                              required: true,
                              key: const Key('product-name-field'),
                            ),
                            _ImageEditor(
                              imageUrl: draft.imageUrl,
                              error: state.fieldErrors['imageUrl'],
                              uploadError: state.imageUploadError,
                              localImagePath: _localImagePath,
                              isUploading: state.isUploadingImage,
                              onPick: _pickImage,
                              onDrop: _uploadImage,
                              onRemove:
                                  draft.imageUrl.trim().isEmpty &&
                                      _localImagePath == null
                                  ? null
                                  : _removeImage,
                            ),
                            _text(
                              context.l10n.productEditorDefaultDescription,
                              draft.description,
                              (value) => cubit.updateDraft(
                                draft.copyWith(description: value),
                              ),
                              error: state.fieldErrors['description'],
                              lines: 4,
                              span: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ContentSection(
                        title:
                            l10n?.productUxClassification ?? 'Classification',
                        description:
                            context.l10n.productEditorClassificationHelp,
                        trailingAction: TextButton.icon(
                          onPressed: () => context
                              .push('/menu-management/catalog-setup')
                              .then((_) => cubit.refreshReferences()),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(
                            l10n?.productUxManageCatalogSetup ??
                                'Manage catalog setup',
                          ),
                        ),
                        child: _FormGrid(
                          children: <Widget>[
                            _select<int>(
                              context.l10n.productOverviewCategory,
                              draft.categoryId,
                              state.categories
                                  .map(
                                    (item) => DropdownMenuItem<int>(
                                      value: item.id,
                                      child: Text(
                                        '${item.name}${item.isActive ? '' : ' (${context.l10n.commonArchived})'}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              (value) => cubit.updateDraft(
                                draft.copyWith(
                                  categoryId: value,
                                  clearCategory: value == null,
                                ),
                              ),
                              state.fieldErrors['categoryId'],
                              required: true,
                            ),
                            _select<int>(
                              context.l10n.productOverviewKitchenStation,
                              draft.kitchenStationId,
                              state.kitchenStations
                                  .map(
                                    (item) => DropdownMenuItem<int>(
                                      value: item.id,
                                      child: Text(
                                        '${item.name}${item.isActive ? '' : ' (${context.l10n.commonArchived})'}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              (value) => cubit.updateDraft(
                                draft.copyWith(
                                  kitchenStationId: value,
                                  clearKitchenStation: value == null,
                                ),
                              ),
                              state.fieldErrors['kitchenStationId'],
                              helper:
                                  context.l10n.productEditorKitchenStationHelp,
                            ),
                            _select<int>(
                              context.l10n.productOverviewReportingCategory,
                              draft.reportingCategoryId,
                              state.reportingCategories
                                  .map(
                                    (item) => DropdownMenuItem<int>(
                                      value: item.id,
                                      child: Text(
                                        '${item.name}${item.isActive ? '' : ' (${context.l10n.commonArchived})'}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              (value) => cubit.updateDraft(
                                draft.copyWith(
                                  reportingCategoryId: value,
                                  clearReportingCategory: value == null,
                                ),
                              ),
                              state.fieldErrors['reportingCategoryId'],
                              helper: context
                                  .l10n
                                  .productEditorReportingCategoryHelp,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ContentSection(
                        title:
                            l10n?.productUxSellingPreparation ??
                            'Selling & Preparation',
                        description:
                            context.l10n.productEditorSellingPreparationHelp,
                        child: _FormGrid(
                          children: <Widget>[
                            _select<String>(
                              context.l10n.productEditorProductType,
                              draft.productType,
                              <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'standard',
                                  child: Text(
                                    context.l10n.productEditorStandard,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'open_price',
                                  child: Text(
                                    context.l10n.productEditorOpenPrice,
                                  ),
                                ),
                              ],
                              (value) => cubit.updateDraft(
                                draft.copyWith(
                                  productType: value ?? 'standard',
                                ),
                              ),
                              state.fieldErrors['productType'],
                            ),
                            _text(
                              context.l10n.productEditorPreparationTime,
                              draft.preparationTimeMinutes,
                              (value) => cubit.updateDraft(
                                draft.copyWith(preparationTimeMinutes: value),
                              ),
                              error:
                                  state.fieldErrors['preparationTimeMinutes'],
                              digits: true,
                              suffix: context.l10n.productEditorMinutes,
                            ),
                            _StockTracking(
                              value: draft.isStockTracked,
                              onChanged: (value) => cubit.updateDraft(
                                draft.copyWith(isStockTracked: value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (_isCreate)
                        ContentSection(
                          title:
                              l10n?.productUxInitialSellingOption ??
                              'Initial selling option',
                          description:
                              context.l10n.productEditorInitialOptionHelp,
                          child: _FormGrid(
                            children: <Widget>[
                              _text(
                                context.l10n.productEditorVariantName,
                                draft.variantName,
                                (value) => cubit.updateDraft(
                                  draft.copyWith(variantName: value),
                                ),
                                error: state.fieldErrors['variants.0.name'],
                                required: true,
                              ),
                              _text(
                                context.l10n.productOverviewBasePrice,
                                draft.variantBasePrice,
                                (value) => cubit.updateDraft(
                                  draft.copyWith(variantBasePrice: value),
                                ),
                                error: localizedConfiguredPriceError(
                                  context,
                                  state.fieldErrors['variants.0.basePrice'],
                                ),
                                price: true,
                                required: draft.productType == 'standard',
                                prefix: 'SYP',
                              ),
                            ],
                          ),
                        )
                      else
                        ContentSection(
                          title: context.l10n.productEditorDefaultVariant,
                          description:
                              context.l10n.productEditorDefaultVariantHelp,
                          child: _DefaultVariantSummary(
                            variant: state.currentDefaultVariant,
                            onManage: () => context.guardedGo(
                              MenuManagementRouteLocations.productWorkspace(
                                widget.productId!,
                                tab: ProductWorkspaceTab.variants,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      ContentSection(
                        title: l10n?.productUxTranslations ?? 'Translations',
                        description: context.l10n.productEditorTranslationsHelp,
                        trailingAction: FilledButton.tonal(
                          key: const Key('product-translations-action'),
                          onPressed: () => _showTranslations(draft),
                          child: Text(_translationSummary(draft)),
                        ),
                        child: Text(
                          context.l10n.productEditorTranslationsPanelHelp,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      DetailsDisclosure(
                        title: l10n?.productUxAdvanced ?? 'Advanced',
                        child: _FormGrid(
                          children: <Widget>[
                            _text(
                              context.l10n.productEditorSortOrder,
                              draft.sortOrder,
                              (value) => cubit.updateDraft(
                                draft.copyWith(sortOrder: value),
                              ),
                              error: state.fieldErrors['sortOrder'],
                              digits: true,
                            ),
                            if (_isCreate) ...<Widget>[
                              _text(
                                context.l10n.productEditorVariantCost,
                                draft.variantCostPrice,
                                (value) => cubit.updateDraft(
                                  draft.copyWith(variantCostPrice: value),
                                ),
                                error:
                                    state.fieldErrors['variants.0.costPrice'],
                                price: true,
                                prefix: 'SYP',
                              ),
                              _text(
                                'SKU',
                                draft.variantSku,
                                (value) => cubit.updateDraft(
                                  draft.copyWith(variantSku: value),
                                ),
                                error: state.fieldErrors['variants.0.sku'],
                                technical: true,
                              ),
                              _text(
                                'Barcode',
                                draft.variantBarcode,
                                (value) => cubit.updateDraft(
                                  draft.copyWith(variantBarcode: value),
                                ),
                                error: state.fieldErrors['variants.0.barcode'],
                                technical: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        StickyFormActions(
          cancelLabel: l10n?.productUxCancel ?? 'Cancel',
          onCancel: _leaveToReturnLocation,
          primaryLabel: _isCreate
              ? l10n?.productUxCreateProduct ?? 'Create Product'
              : l10n?.productUxSaveChanges ?? 'Save Changes',
          onSave: state.isReadOnly ? null : cubit.submit,
          isDirty: state.isDirty,
          isSaving: state.status == ProductEditorStatus.submitting,
          validationSummary: validation,
          primaryActionKey: const Key('product-editor-save'),
        ),
      ],
    );
  }

  String _translationSummary(ProductEditorDraft draft) {
    final List<String> configured = <String>[
      if (draft.nameAr.trim().isNotEmpty ||
          draft.descriptionAr.trim().isNotEmpty)
        'Arabic configured',
      if (draft.nameEn.trim().isNotEmpty ||
          draft.descriptionEn.trim().isNotEmpty)
        'English configured',
    ];
    return configured.isEmpty ? 'Translations' : configured.join(' · ');
  }

  Future<void> _pickImage() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    final String? path = result?.files.single.path;
    if (path != null) await _uploadImage(path);
  }

  Future<void> _uploadImage(String path) async {
    if (!mounted) return;
    setState(() => _localImagePath = path);
    await context.read<ProductEditorCubit>().uploadImage(path);
    if (!mounted) return;
    if (context.read<ProductEditorCubit>().state.imageUploadError == null) {
      setState(() => _localImagePath = null);
    }
  }

  void _removeImage() {
    setState(() => _localImagePath = null);
    context.read<ProductEditorCubit>().updateDraft(
      context.read<ProductEditorCubit>().state.draft.copyWith(imageUrl: ''),
    );
  }

  Future<void> _showTranslations(ProductEditorDraft draft) {
    final ValueChanged<ProductEditorDraft> onChanged = context
        .read<ProductEditorCubit>()
        .updateDraft;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close translations',
      pageBuilder: (context, _, _) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Material(
          child: SafeArea(
            child: SizedBox(
              width: 520,
              child: _TranslationSheet(draft: draft, onChanged: onChanged),
            ),
          ),
        ),
      ),
    );
  }

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
    String? prefix,
    String? suffix,
    bool span = false,
    bool technical = false,
    Key? key,
  }) => _GridField(
    span: span,
    child: TextFormField(
      key: key,
      initialValue: value,
      maxLines: lines,
      textDirection: technical || price ? TextDirection.ltr : null,
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
        prefixText: prefix,
        suffixText: suffix,
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
    String? helper,
  }) => _GridField(
    child: DropdownButtonFormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      isExpanded: true,
      hint: Text(context.l10n.productEditorNone),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        errorText: error,
        helperText: helper,
      ),
      items: items,
      onChanged: onChanged,
    ),
  );

  Future<bool> _mayLeave() async {
    final ProductEditorState state = context.read<ProductEditorCubit>().state;
    if (!state.isDirty) return true;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.menuUiUnsavedChangesTitle),
        content: Text(context.l10n.menuUiUnsavedChangesMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.menuUiStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.menuUiLeaveWithoutSaving),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _leaveToReturnLocation() async {
    if (await _mayLeave() && mounted) context.go(_returnLocation);
  }
}

class _FormGrid extends StatelessWidget {
  const _FormGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bool twoColumns = constraints.maxWidth >= 760;
      return Wrap(
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: children.map((child) {
          final bool span = child is _GridField && child.span;
          return SizedBox(
            width: twoColumns && !span
                ? (constraints.maxWidth - AppSpacing.lg) / 2
                : constraints.maxWidth,
            child: child,
          );
        }).toList(),
      );
    },
  );
}

class _GridField extends StatelessWidget {
  const _GridField({required this.child, this.span = false});
  final Widget child;
  final bool span;
  @override
  Widget build(BuildContext context) => child;
}

class _ImageEditor extends StatelessWidget {
  const _ImageEditor({
    required this.imageUrl,
    required this.error,
    required this.onPick,
    required this.onDrop,
    this.localImagePath,
    this.uploadError,
    this.isUploading = false,
    this.onRemove,
  });
  final String imageUrl;
  final String? error;
  final String? localImagePath;
  final String? uploadError;
  final bool isUploading;
  final VoidCallback onPick;
  final ValueChanged<String> onDrop;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) => _GridField(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.productEditorImage,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        DropTarget(
          onDragDone: (detail) {
            if (detail.files.isNotEmpty) onDrop(detail.files.first.path);
          },
          child: InkWell(
            onTap: isUploading ? null : onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 152,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(
                  color: isUploading ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isUploading
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(context.l10n.productEditorUploadingImage),
                      ],
                    )
                  : localImagePath != null
                  ? Image.file(
                      File(localImagePath!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _ImagePlaceholder(
                        message: context.l10n.productEditorPreviewUnavailable,
                      ),
                    )
                  : imageUrl.trim().isEmpty
                  ? _ImagePlaceholder(
                      message: context.l10n.productEditorDropImage,
                    )
                  : Image.network(
                      imageUrl.trim(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _ImagePlaceholder(
                        message: context.l10n.productEditorImageLoadFailed,
                      ),
                    ),
            ),
          ),
        ),
        if (error != null || uploadError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            error ?? uploadError!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            OutlinedButton(
              key: const Key('product-image-action'),
              onPressed: isUploading ? null : onPick,
              child: Text(
                imageUrl.trim().isEmpty
                    ? context.l10n.productEditorChooseImage
                    : context.l10n.productEditorChangeImage,
              ),
            ),
            if (onRemove != null)
              TextButton(
                onPressed: isUploading ? null : onRemove,
                child: Text(context.l10n.productEditorRemoveImage),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      const Icon(Icons.image_outlined, size: 36),
      const SizedBox(height: AppSpacing.xs),
      Text(message),
      const SizedBox(height: AppSpacing.xs),
      Text(context.l10n.productEditorImageFormats),
    ],
  );
}

class _StockTracking extends StatelessWidget {
  const _StockTracking({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => _GridField(
    span: true,
    child: Material(
      color: Colors.transparent,
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(context.l10n.productEditorStockTracking),
        subtitle: Text(context.l10n.productEditorStockTrackingHelp),
        value: value,
        onChanged: onChanged,
      ),
    ),
  );
}

class _DefaultVariantSummary extends StatelessWidget {
  const _DefaultVariantSummary({required this.variant, required this.onManage});
  final ProductVariant? variant;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(variant?.name ?? context.l10n.productEditorNoDefaultVariant),
            if (variant != null)
              Text(
                context.l10n.productEditorBasePriceValue(
                  catalogMoney(context, variant!.basePrice),
                ),
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
      OutlinedButton.icon(
        onPressed: onManage,
        icon: const Icon(Icons.tune_outlined),
        label: Text(context.l10n.productEditorManageVariants),
      ),
    ],
  );
}

class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({required this.draft, required this.onChanged});
  final ProductEditorDraft draft;
  final ValueChanged<ProductEditorDraft> onChanged;
  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late ProductEditorDraft _draft = widget.draft;
  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _update(ProductEditorDraft draft) {
    setState(() => _draft = draft);
    widget.onChanged(draft);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Padding(
        padding: AppSpacing.allLg,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Translations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: context.l10n.productEditorTranslationsClose,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
      TabBar(
        controller: _tabs,
        tabs: const <Widget>[
          Tab(text: 'Arabic'),
          Tab(text: 'English'),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _TranslationFields(
              key: const Key('arabic-translation-fields'),
              defaultName: _draft.name,
              defaultDescription: _draft.description,
              name: _draft.nameAr,
              description: _draft.descriptionAr,
              onNameChanged: (value) => _update(_draft.copyWith(nameAr: value)),
              onDescriptionChanged: (value) =>
                  _update(_draft.copyWith(descriptionAr: value)),
            ),
            _TranslationFields(
              key: const Key('english-translation-fields'),
              defaultName: _draft.name,
              defaultDescription: _draft.description,
              name: _draft.nameEn,
              description: _draft.descriptionEn,
              onNameChanged: (value) => _update(_draft.copyWith(nameEn: value)),
              onDescriptionChanged: (value) =>
                  _update(_draft.copyWith(descriptionEn: value)),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TranslationFields extends StatelessWidget {
  const _TranslationFields({
    super.key,
    required this.defaultName,
    required this.defaultDescription,
    required this.name,
    required this.description,
    required this.onNameChanged,
    required this.onDescriptionChanged,
  });
  final String defaultName;
  final String defaultDescription;
  final String name;
  final String description;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: AppSpacing.allLg,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.productEditorDefaultContent,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(defaultName.isEmpty ? '—' : defaultName),
        if (defaultDescription.isNotEmpty) Text(defaultDescription),
        const SizedBox(height: AppSpacing.xl),
        TextFormField(
          initialValue: name,
          onChanged: onNameChanged,
          decoration: InputDecoration(
            labelText: context.l10n.productEditorLocalizedName,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          initialValue: description,
          maxLines: 5,
          onChanged: onDescriptionChanged,
          decoration: InputDecoration(
            labelText: context.l10n.productEditorLocalizedDescription,
          ),
        ),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: AppSpacing.allMd,
    color: AppColors.discountOrangeBadge,
    child: Text(message),
  );
}
