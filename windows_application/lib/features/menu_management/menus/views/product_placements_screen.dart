// ignore_for_file: curly_braces_in_flow_control_structures, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../models/catalog_models.dart';
import '../controllers/product_placements_cubit.dart';
import '../models/menu_models.dart';
import '../models/product_placement.dart';

class ProductPlacementsScreen extends StatefulWidget {
  const ProductPlacementsScreen({super.key, required this.menuId});
  final int menuId;
  @override
  State<ProductPlacementsScreen> createState() =>
      _ProductPlacementsScreenState();
}

class _ProductPlacementsScreenState extends State<ProductPlacementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductPlacementsCubit>().load(widget.menuId),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ProductPlacementsCubit, ProductPlacementsState>(
    listenWhen: (a, b) =>
        a.successMessage != b.successMessage ||
        a.errorMessage != b.errorMessage,
    listener: (_, state) {
      final message = state.successMessage ?? state.errorMessage;
      if (message != null)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
    },
    builder: (context, state) {
      final cubit = context.read<ProductPlacementsCubit>();
      final menu = state.menu;
      if (menu == null) {
        return DesktopPageLayout(
          child: Center(
            child: state.status == PlacementStatus.loading
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: () => cubit.load(widget.menuId),
                    child: Text(state.errorMessage ?? 'Menu not found. Retry'),
                  ),
          ),
        );
      }
      final sections = [...menu.sections]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return DesktopPageLayout(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        context.go('/menu-management/menus/${menu.id}'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                  Text(
                    menu.localizedName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text('Product Placements'),
                  SegmentedButton<PlacementFilter>(
                    segments: const [
                      ButtonSegment(
                        value: PlacementFilter.active,
                        label: Text('Active'),
                      ),
                      ButtonSegment(
                        value: PlacementFilter.archived,
                        label: Text('Archived'),
                      ),
                      ButtonSegment(
                        value: PlacementFilter.all,
                        label: Text('All'),
                      ),
                    ],
                    selected: {state.filter},
                    onSelectionChanged: state.isBusy
                        ? null
                        : (values) => cubit.setFilter(values.first),
                  ),
                  OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => cubit.load(menu.id, refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (menu.isArchived)
                const _Notice(
                  'This menu is archived and read-only. Placement history remains diagnostic.',
                ),
              if (sections.isEmpty)
                const _Empty('No sections have been created for this menu.'),
              for (final section in sections)
                _section(context, state, section, sections),
            ],
          ),
        ),
      );
    },
  );

  Widget _section(
    BuildContext context,
    ProductPlacementsState state,
    MenuSectionRecord section,
    List<MenuSectionRecord> allSections,
  ) {
    final mutable = !state.readOnly && !section.isArchived && section.isActive;
    final placements = state.forSection(section.id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.localizedName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${section.isArchived
                            ? 'Archived'
                            : section.isActive
                            ? 'Visible / Active'
                            : 'Visible / Inactive'} / ${section.placementCount} placements',
                      ),
                    ],
                  ),
                ),
                if (mutable)
                  FilledButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => _pick(context, section.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                  ),
              ],
            ),
            if (section.isArchived)
              const _Notice(
                'This section is archived. Its placements cannot be changed.',
              ),
            if (placements.isEmpty)
              _Empty(
                state.filter == PlacementFilter.archived
                    ? 'No archived placements are available.'
                    : 'No products have been placed in this section.',
              ),
            for (var index = 0; index < placements.length; index++)
              _row(
                context,
                state,
                placements[index],
                index,
                placements.length,
                mutable,
                allSections,
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ProductPlacementsState state,
    ProductPlacement placement,
    int index,
    int count,
    bool sectionMutable,
    List<MenuSectionRecord> sections,
  ) {
    final product = placement.product;
    final canMutate = sectionMutable && !placement.isArchived;
    final productStatus = product?.isArchived == true
        ? 'Product archived'
        : product?.isActive == false
        ? 'Product inactive'
        : 'Product active';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundImage: product?.imageUrl?.isNotEmpty == true
            ? NetworkImage(product!.imageUrl!)
            : null,
        child: product?.imageUrl?.isNotEmpty == true
            ? null
            : const Icon(Icons.inventory_2),
      ),
      title: Text(placement.displayName),
      subtitle: Text(
        '${product?.defaultVariant?.name ?? 'No default variant'} / ${product?.defaultVariant?.basePrice ?? '-'}\n$productStatus / ${placement.isVisible ? 'Placement visible' : 'Placement hidden'} / ${placement.isArchived ? 'Placement archived' : 'Placement active'}',
      ),
      isThreeLine: true,
      trailing: Wrap(
        children: [
          Text('Order ${placement.sortOrder}'),
          IconButton(
            tooltip: 'Move Up',
            onPressed: state.isBusy || !canMutate || index == 0
                ? null
                : () => context.read<ProductPlacementsCubit>().reorder(
                    placement.sectionId,
                    index,
                    index - 1,
                  ),
            icon: const Icon(Icons.arrow_upward),
          ),
          IconButton(
            tooltip: 'Move Down',
            onPressed: state.isBusy || !canMutate || index == count - 1
                ? null
                : () => context.read<ProductPlacementsCubit>().reorder(
                    placement.sectionId,
                    index,
                    index + 1,
                  ),
            icon: const Icon(Icons.arrow_downward),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _action(context, value, placement, sections),
            itemBuilder: (_) => [
              if (canMutate)
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit Placement'),
                ),
              if (canMutate)
                const PopupMenuItem(
                  value: 'move',
                  child: Text('Move to Section'),
                ),
              if (canMutate)
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              if (placement.isArchived && sectionMutable)
                const PopupMenuItem(value: 'restore', child: Text('Restore')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, int sectionId) async {
    final cubit = context.read<ProductPlacementsCubit>();
    final product = await showDialog<ProductSummary>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ProductPicker(sectionId: sectionId),
      ),
    );
    if (product != null && context.mounted)
      await context.read<ProductPlacementsCubit>().create(
        sectionId,
        ProductPlacementDraft(productId: product.id),
      );
  }

  Future<void> _action(
    BuildContext context,
    String action,
    ProductPlacement placement,
    List<MenuSectionRecord> sections,
  ) async {
    final cubit = context.read<ProductPlacementsCubit>();
    if (action == 'edit') {
      final draft = await showDialog<ProductPlacementDraft>(
        context: context,
        builder: (_) => _Editor(placement),
      );
      if (draft != null && context.mounted)
        await cubit.update(placement.id, draft);
    }
    if (action == 'move') {
      final target = await showDialog<int>(
        context: context,
        builder: (_) => _Move(placement, sections),
      );
      if (target != null && context.mounted)
        await cubit.move(placement, target);
    }
    if (action == 'archive' && await _confirm(context, true))
      await cubit.archive(placement.id);
    if (action == 'restore' && await _confirm(context, false))
      await cubit.restore(placement.id);
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.sectionId});
  final int sectionId;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ProductPlacementsCubit>().searchProducts(
        '',
        sectionId: widget.sectionId,
      ),
    );
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add Product'),
    content: SizedBox(
      width: 620,
      height: 450,
      child: BlocBuilder<ProductPlacementsCubit, ProductPlacementsState>(
        builder: (context, state) {
          final cubit = context.read<ProductPlacementsCubit>();
          return Column(
            children: [
              TextField(
                controller: search,
                onSubmitted: (_) => cubit.searchProducts(
                  search.text,
                  sectionId: widget.sectionId,
                ),
                decoration: InputDecoration(
                  hintText: 'Search catalog products',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => cubit.searchProducts(
                      search.text,
                      sectionId: widget.sectionId,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: state.pickerLoading && state.pickerProducts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.pickerErrorMessage != null &&
                          state.pickerProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(state.pickerErrorMessage!),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => cubit.searchProducts(
                                search.text,
                                sectionId: widget.sectionId,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : state.pickerProducts.isEmpty
                    ? const Center(
                        child: Text('No products match the current search.'),
                      )
                    : ListView(
                        children: [
                          for (final product in state.pickerProducts)
                            ListTile(
                              title: Text(
                                product.nameEn?.isNotEmpty == true
                                    ? product.nameEn!
                                    : product.name,
                              ),
                              subtitle: Text(
                                product.category?.name ?? product.productType,
                              ),
                              trailing: const Icon(Icons.add_circle_outline),
                              onTap: () => Navigator.pop(context, product),
                            ),
                          if (state.pickerHasMore)
                            TextButton(
                              onPressed: state.pickerLoading
                                  ? null
                                  : () => cubit.searchProducts(
                                      search.text,
                                      sectionId: widget.sectionId,
                                      next: true,
                                    ),
                              child: const Text('Load more'),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _Editor extends StatefulWidget {
  const _Editor(this.placement);
  final ProductPlacement placement;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late bool visible, featured;
  late final TextEditingController name, description, image;
  @override
  void initState() {
    super.initState();
    final p = widget.placement;
    visible = p.isVisible;
    featured = p.isFeatured;
    name = TextEditingController(text: p.displayNameOverride);
    description = TextEditingController(text: p.displayDescriptionOverride);
    image = TextEditingController(text: p.displayImageOverride);
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit Placement'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hidden placements remain stored but are excluded from visible Menu output. Placement archival is separate from Product archival.',
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Display name override',
            ),
          ),
          TextField(
            controller: description,
            decoration: const InputDecoration(
              labelText: 'Display description override',
            ),
          ),
          TextField(
            controller: image,
            decoration: const InputDecoration(
              labelText: 'Display image URL override',
            ),
          ),
          SwitchListTile(
            title: const Text('Visible'),
            value: visible,
            onChanged: (v) => setState(() => visible = v),
          ),
          SwitchListTile(
            title: const Text('Featured'),
            value: featured,
            onChanged: (v) => setState(() => featured = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          ProductPlacementDraft(
            displayNameOverride: name.text.trim(),
            displayDescriptionOverride: description.text.trim(),
            displayImageOverride: image.text.trim(),
            sortOrder: widget.placement.sortOrder,
            isVisible: visible,
            isFeatured: featured,
          ),
        ),
        child: const Text('Save'),
      ),
    ],
  );
}

class _Move extends StatelessWidget {
  const _Move(this.placement, this.sections);
  final ProductPlacement placement;
  final List<MenuSectionRecord> sections;
  @override
  Widget build(BuildContext context) {
    final eligible = sections.where(
      (s) => s.id != placement.sectionId && !s.isArchived && s.isActive,
    );
    return AlertDialog(
      title: const Text('Move to Section'),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final section in eligible)
              ListTile(
                title: Text(section.localizedName),
                onTap: () => Navigator.pop(context, section.id),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<bool> _confirm(BuildContext context, bool archive) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(archive ? 'Archive placement?' : 'Restore placement?'),
        content: Text(
          archive
              ? 'The Product remains in the Catalog and is not deleted. Historical Published Versions remain unchanged. The Placement can be restored later; Preview/Publish determine future output.'
              : 'Restoring returns this Placement to the editable Menu. It does not publish the Menu, restore an archived Product, or make a hidden Placement visible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(archive ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    ) ??
    false;

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Text(text),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(24), child: Text(text));
}
