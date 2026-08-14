// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/localization_extensions.dart';
import '../../../../shared/layouts/desktop_page_layout.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../widgets/menu_management_tabs.dart';
import '../controllers/catalog_setup_cubit.dart';
import '../models/catalog_setup_models.dart';

class CatalogSetupScreen extends StatefulWidget {
  const CatalogSetupScreen({super.key, required this.initialKind});
  final CatalogSetupKind initialKind;
  @override
  State<CatalogSetupScreen> createState() => _CatalogSetupScreenState();
}

class _CatalogSetupScreenState extends State<CatalogSetupScreen> {
  final TextEditingController _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CatalogSetupCubit>().initialize(widget.initialKind),
    );
  }

  @override
  void didUpdateWidget(covariant CatalogSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialKind == widget.initialKind) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CatalogSetupCubit>().selectKind(widget.initialKind);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<CatalogSetupCubit, CatalogSetupState>(
    listener: (context, state) {
      if (_search.text != state.search) {
        _search.value = TextEditingValue(
          text: state.search,
          selection: TextSelection.collapsed(offset: state.search.length),
        );
      }
      if (state.message != null)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.message!)));
    },
    builder: (context, state) {
      final cubit = context.read<CatalogSetupCubit>();
      return DesktopPageLayout(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.navigationMenuManagement,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.catalogSetupTitle,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const MenuManagementTabs(selected: 'catalog-setup'),
              const SizedBox(height: 20),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _title(context, state.kind),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(_explanation(context, state.kind)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _kindButton(
                          context,
                          state,
                          CatalogSetupKind.categories,
                          context.l10n.catalogSetupCategoriesTitle,
                        ),
                        _kindButton(
                          context,
                          state,
                          CatalogSetupKind.reportingCategories,
                          context.l10n.catalogSetupReportingCategoriesTitle,
                        ),
                        _kindButton(
                          context,
                          state,
                          CatalogSetupKind.kitchenStations,
                          context.l10n.catalogSetupKitchenStationsTitle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AppCard(
                  child: Column(
                    children: <Widget>[
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: _search,
                              decoration: InputDecoration(
                                labelText: context.l10n.commonSearch,
                              ),
                              onSubmitted: cubit.setSearch,
                            ),
                          ),
                          DropdownButton<CatalogSetupStatus>(
                            value: state.status,
                            items: CatalogSetupStatus.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(_status(context, value)),
                                  ),
                                )
                                .toList(),
                            onChanged: state.isBusy
                                ? null
                                : (value) {
                                    if (value != null) cubit.setStatus(value);
                                  },
                          ),
                          OutlinedButton.icon(
                            onPressed: state.isBusy ? null : cubit.load,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.commonRefresh),
                          ),
                          FilledButton.icon(
                            onPressed: state.isBusy
                                ? null
                                : () => _form(context),
                            icon: const Icon(Icons.add),
                            label: Text(
                              context.l10n.catalogSetupCreate(
                                _singular(context, state.kind),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (state.requestStatus ==
                              CatalogSetupRequestStatus.loading &&
                          state.page == null)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (state.requestStatus ==
                              CatalogSetupRequestStatus.failure &&
                          state.page == null)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  state.error ??
                                      context.l10n.catalogSetupUnableToLoad,
                                ),
                                TextButton(
                                  onPressed: cubit.load,
                                  child: Text(context.l10n.commonRetry),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (state.page == null || state.page!.items.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              context.l10n.catalogSetupNoMatchingRecords,
                            ),
                          ),
                        )
                      else
                        Expanded(child: _table(context, state)),
                      if (state.page != null) _pagination(context, state),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _kindButton(
    BuildContext context,
    CatalogSetupState state,
    CatalogSetupKind kind,
    String label,
  ) => ChoiceChip(
    label: Text(label),
    selected: state.kind == kind,
    onSelected: (_) {
      context.go('/menu-management/catalog-setup?tab=${kind.queryValue}');
      context.read<CatalogSetupCubit>().selectKind(kind);
    },
  );
  Widget _table(BuildContext context, CatalogSetupState state) {
    final records = state.page!.items;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: <DataColumn>[
          DataColumn(label: Text(context.l10n.catalogSetupName)),
          if (state.kind == CatalogSetupKind.kitchenStations)
            DataColumn(label: Text(context.l10n.catalogSetupCodePrinter)),
          DataColumn(label: Text(context.l10n.catalogSetupProducts)),
          DataColumn(label: Text(context.l10n.menuPublishStatus)),
          DataColumn(label: Text(context.l10n.catalogSetupOrder)),
          DataColumn(label: Text(context.l10n.catalogSetupActions)),
        ],
        rows: records.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return DataRow(
            cells: <DataCell>[
              DataCell(Text(item.name)),
              if (state.kind == CatalogSetupKind.kitchenStations)
                DataCell(
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      <String>[
                        item.code,
                        item.printerName,
                      ].where((value) => value.isNotEmpty).join(' · '),
                    ),
                  ),
                ),
              DataCell(Text('${item.productCount}')),
              DataCell(
                Text(
                  item.isActive
                      ? context.l10n.commonActive
                      : context.l10n.statusArchived,
                ),
              ),
              DataCell(Text('${item.sortOrder}')),
              DataCell(
                Wrap(
                  children: <Widget>[
                    IconButton(
                      tooltip: context.l10n.commonEdit,
                      onPressed: state.isBusy
                          ? null
                          : () => _form(context, item),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (item.isActive)
                      IconButton(
                        tooltip: context.l10n.catalogSetupArchive(
                          _singular(context, state.kind),
                        ),
                        onPressed: state.isBusy
                            ? null
                            : () => _confirmArchive(context, item),
                        icon: const Icon(Icons.archive_outlined),
                      )
                    else
                      IconButton(
                        tooltip: context.l10n.catalogSetupRestore,
                        onPressed: state.isBusy
                            ? null
                            : () => context.read<CatalogSetupCubit>().restore(
                                item.id,
                              ),
                        icon: const Icon(Icons.restore),
                      ),
                    IconButton(
                      tooltip: context.l10n.catalogSetupMoveUp,
                      onPressed: index == 0 || state.isBusy
                          ? null
                          : () => context.read<CatalogSetupCubit>().move(
                              item.id,
                              -1,
                            ),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: context.l10n.catalogSetupMoveDown,
                      onPressed: index == records.length - 1 || state.isBusy
                          ? null
                          : () => context.read<CatalogSetupCubit>().move(
                              item.id,
                              1,
                            ),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _pagination(BuildContext context, CatalogSetupState state) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: <Widget>[
      Text(context.l10n.catalogSetupPage(state.page!.meta.currentPage)),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: state.page!.meta.currentPage <= 1 || state.isBusy
            ? null
            : () => context.read<CatalogSetupCubit>().load(
                page: state.page!.meta.currentPage - 1,
              ),
        child: Text(context.l10n.catalogSetupPrevious),
      ),
      const SizedBox(width: 8),
      OutlinedButton(
        onPressed: !state.page!.meta.hasNextPage || state.isBusy
            ? null
            : () => context.read<CatalogSetupCubit>().load(
                page: state.page!.meta.currentPage + 1,
              ),
        child: Text(context.l10n.catalogSetupNext),
      ),
    ],
  );
  Future<void> _confirmArchive(
    BuildContext context,
    CatalogSetupRecord item,
  ) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          context.l10n.catalogSetupArchive(
            _singular(context, context.read<CatalogSetupCubit>().state.kind),
          ),
        ),
        content: Text(
          context.l10n.catalogSetupArchiveConfirmation(
            item.name,
            item.productCount,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(
              context.l10n.catalogSetupArchive(
                _singular(
                  context,
                  context.read<CatalogSetupCubit>().state.kind,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (yes == true && context.mounted)
      await context.read<CatalogSetupCubit>().archive(item.id);
  }

  Future<void> _form(BuildContext context, [CatalogSetupRecord? record]) async {
    final kind = context.read<CatalogSetupCubit>().state.kind;
    final draft = CatalogSetupDraft.fromRecord(
      record ??
          const CatalogSetupRecord(
            id: 0,
            name: '',
            nameAr: '',
            nameEn: '',
            description: '',
            code: '',
            printerName: '',
            branchId: null,
            isActive: true,
            sortOrder: 0,
            productCount: 0,
          ),
    );
    final name = TextEditingController(text: draft.name);
    final nameAr = TextEditingController(text: draft.nameAr);
    final nameEn = TextEditingController(text: draft.nameEn);
    final code = TextEditingController(text: draft.code);
    final printer = TextEditingController(text: draft.printerName);
    final description = TextEditingController(text: draft.description);
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          record == null
              ? context.l10n.catalogSetupCreate(_singular(context, kind))
              : context.l10n.catalogSetupEdit(_singular(context, kind)),
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: context.l10n.catalogSetupName,
                  ),
                ),
                if (kind != CatalogSetupKind.categories) ...<Widget>[
                  TextField(
                    controller: nameAr,
                    decoration: InputDecoration(
                      labelText: context.l10n.catalogSetupNameArabic,
                    ),
                  ),
                  TextField(
                    controller: nameEn,
                    decoration: InputDecoration(
                      labelText: context.l10n.catalogSetupNameEnglish,
                    ),
                  ),
                ],
                if (kind != CatalogSetupKind.categories)
                  TextField(
                    controller: code,
                    decoration: InputDecoration(
                      labelText: context.l10n.catalogSetupCode,
                    ),
                  ),
                if (kind != CatalogSetupKind.kitchenStations)
                  TextField(
                    controller: description,
                    decoration: InputDecoration(
                      labelText: context.l10n.catalogSetupDescription,
                    ),
                  ),
                if (kind == CatalogSetupKind.kitchenStations)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: printer,
                      decoration: InputDecoration(
                        labelText: context.l10n.catalogSetupPrinterName,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final next = CatalogSetupDraft(
                name: name.text,
                nameAr: nameAr.text,
                nameEn: nameEn.text,
                code: code.text,
                printerName: printer.text,
                description: description.text,
                isActive: draft.isActive,
              );
              if (record == null) {
                await context.read<CatalogSetupCubit>().create(next);
              } else {
                await context.read<CatalogSetupCubit>().update(record.id, next);
              }
              if (dialog.mounted &&
                  context.read<CatalogSetupCubit>().state.requestStatus !=
                      CatalogSetupRequestStatus.failure)
                Navigator.pop(dialog);
            },
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    name.dispose();
    nameAr.dispose();
    nameEn.dispose();
    code.dispose();
    printer.dispose();
    description.dispose();
  }

  String _title(BuildContext context, CatalogSetupKind kind) => switch (kind) {
    CatalogSetupKind.categories => context.l10n.catalogSetupCategoriesTitle,
    CatalogSetupKind.reportingCategories =>
      context.l10n.catalogSetupReportingCategoriesTitle,
    CatalogSetupKind.kitchenStations =>
      context.l10n.catalogSetupKitchenStationsTitle,
  };
  String _singular(BuildContext context, CatalogSetupKind kind) =>
      switch (kind) {
        CatalogSetupKind.categories => context.l10n.catalogSetupCategory,
        CatalogSetupKind.reportingCategories =>
          context.l10n.catalogSetupReportingCategory,
        CatalogSetupKind.kitchenStations =>
          context.l10n.catalogSetupKitchenStation,
      };
  String _explanation(BuildContext context, CatalogSetupKind kind) =>
      switch (kind) {
        CatalogSetupKind.categories =>
          context.l10n.catalogSetupCategoriesExplanation,
        CatalogSetupKind.reportingCategories =>
          context.l10n.catalogSetupReportingCategoriesExplanation,
        CatalogSetupKind.kitchenStations =>
          context.l10n.catalogSetupKitchenStationsExplanation,
      };
  String _status(BuildContext context, CatalogSetupStatus status) =>
      switch (status) {
        CatalogSetupStatus.active => context.l10n.commonActive,
        CatalogSetupStatus.archived => context.l10n.statusArchived,
        CatalogSetupStatus.all => context.l10n.catalogSetupAll,
      };
}
