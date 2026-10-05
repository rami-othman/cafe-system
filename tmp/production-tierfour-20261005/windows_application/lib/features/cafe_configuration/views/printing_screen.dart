import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../printer/models/receipt_template.dart';
import '../../printer/services/printer_service.dart';
import '../../printer/widgets/printer_config_fields.dart';
import '../../printer/widgets/printer_test_print_control.dart';
import '../controllers/cafe_configuration_cubits.dart';
import '../controllers/printing_cubit.dart';
import '../widgets/receipt_template_preview.dart';

class PrintingScreen extends StatelessWidget {
  const PrintingScreen({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<PrintingCubit, PrintingState>(
    listenWhen: (previous, current) =>
        (previous.printerSaveStatus != current.printerSaveStatus &&
            current.printerSaveStatus == SectionSaveStatus.success) ||
        (previous.templateSaveStatus != current.templateSaveStatus &&
            current.templateSaveStatus == SectionSaveStatus.success),
    listener: (context, state) {
      final l10n = context.l10n;
      final String message =
          state.printerSaveStatus == SectionSaveStatus.success
          ? l10n.cafeConfigurationPrinterConfigSaved
          : l10n.cafeConfigurationReceiptDesignSaved;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    },
    builder: (context, state) {
      final l10n = context.l10n;
      final cubit = context.read<PrintingCubit>();
      if (state.status == CafeConfigurationLoadStatus.failure &&
          state.branches.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.cafeConfigurationCouldNotLoad),
              TextButton(onPressed: cubit.load, child: Text(l10n.commonRetry)),
            ],
          ),
        );
      }
      return SingleChildScrollView(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.cafeConfigurationPrinting,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.cafeConfigurationPrintingSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (state.branches.isEmpty &&
                          state.status != CafeConfigurationLoadStatus.loading)
                        Text(l10n.cafeConfigurationNoBranches)
                      else if (state.branches.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.cafeConfigurationBranchName,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                key: const Key('printing-branch'),
                                isExpanded: true,
                                value: state.selectedBranchId,
                                items: state.branches
                                    .map(
                                      (branch) => DropdownMenuItem(
                                        value: branch.id,
                                        child: Text(branch.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged:
                                    state.status ==
                                        CafeConfigurationLoadStatus.submitting
                                    ? null
                                    : (id) async {
                                        if (id == null) return;
                                        if (state.isDirty) {
                                          final discard = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) => AlertDialog(
                                              content: Text(
                                                l10n.cafeConfigurationPrintingDiscard,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                  child: Text(
                                                    l10n.commonCancel,
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                  child: Text(
                                                    l10n.cafeConfigurationReset,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (discard != true ||
                                              !context.mounted) {
                                            return;
                                          }
                                        }
                                        await cubit.selectBranch(id);
                                      },
                              ),
                            ),
                          ),
                        ),
                      if (state.branch == null &&
                          state.branches.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        state.status == CafeConfigurationLoadStatus.loading
                            ? const CircularProgressIndicator()
                            : TextButton(
                                onPressed: () =>
                                    cubit.selectBranch(state.selectedBranchId!),
                                child: Text(l10n.commonRetry),
                              ),
                      ],
                      if (state.branch != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const Divider(),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.cafeConfigurationReceiptPrinting,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.cafeConfigurationPrintingBranchDefaultsNotice,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Material(
                          color: AppColors.transparent,
                          child: SwitchListTile.adaptive(
                            key: const Key('printing-enabled'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.cafeConfigurationReceiptPrintingEnabled,
                            ),
                            value: state.config.enabled,
                            onChanged: (enabled) => cubit.update(
                              config: state.config.copyWith(enabled: enabled),
                            ),
                          ),
                        ),
                        if (state.config.enabled) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          PrinterConfigFields(
                            nameKey: ValueKey(
                              'printing-name-${state.selectedBranchId}-${state.formVersion}',
                            ),
                            hostKey: ValueKey(
                              'printing-host-${state.selectedBranchId}-${state.formVersion}',
                            ),
                            portKey: ValueKey(
                              'printing-port-${state.selectedBranchId}-${state.formVersion}',
                            ),
                            paperWidthKey: ValueKey(
                              'printing-width-${state.selectedBranchId}-${state.formVersion}',
                            ),
                            config: state.config,
                            enabled: true,
                            onChanged: (config) => cubit.update(config: config),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrinterTestPrintControl(
                            enabled: state.config.isValid,
                            onTest: () => serviceLocator<PrinterService>()
                                .printTestReceipt(
                                  state.config,
                                  Localizations.localeOf(context),
                                ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        const Divider(height: 1),
                        Material(
                          color: AppColors.transparent,
                          child: SwitchListTile.adaptive(
                            key: const Key('printing-auto'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.cafeConfigurationAutoPrint),
                            value: state.autoPrintAfterPayment,
                            onChanged: (value) =>
                                cubit.update(autoPrintAfterPayment: value),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (state.printerSaveError == 'validation')
                          Text(
                            l10n.cafeConfigurationPrinterInvalid,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        if (state.printerSaveError == 'save')
                          Text(
                            l10n.cafeConfigurationSaveFailed,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: <Widget>[
                            const Spacer(),
                            FilledButton(
                              key: const Key('printing-save-printer-config'),
                              onPressed:
                                  state.isPrinterConfigDirty &&
                                      state.printerSaveStatus !=
                                          SectionSaveStatus.submitting
                                  ? cubit.savePrinterConfig
                                  : null,
                              child: Text(
                                l10n.cafeConfigurationSavePrinterConfig,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.receipt_outlined,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.cafeConfigurationReceiptDesign,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            OutlinedButton.icon(
                              key: const Key('printing-receipt-preview'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => Dialog(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                      maxHeight: 700,
                                    ),
                                    child: ReceiptTemplatePreview(
                                      template: state.template,
                                      paperWidth: state.config.paperWidth,
                                    ),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.visibility_outlined),
                              label: Text(l10n.cafeConfigurationReceiptPreview),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _ReceiptDesignSection(state: state, cubit: cubit),
                        if (state.templateSaveError == 'save')
                          Text(
                            l10n.cafeConfigurationSaveFailed,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        const SizedBox(height: AppSpacing.lg),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            TextButton(
                              onPressed: state.isDirty ? cubit.reset : null,
                              child: Text(l10n.cafeConfigurationReset),
                            ),
                            const Spacer(),
                            FilledButton(
                              key: const Key('printing-save-receipt-design'),
                              onPressed:
                                  state.isTemplateDirty &&
                                      state.templateSaveStatus !=
                                          SectionSaveStatus.submitting
                                  ? cubit.saveReceiptTemplate
                                  : null,
                              child: Text(
                                l10n.cafeConfigurationSaveReceiptDesign,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ReceiptDesignSection extends StatelessWidget {
  const _ReceiptDesignSection({required this.state, required this.cubit});

  final PrintingState state;
  final PrintingCubit cubit;

  @override
  Widget build(BuildContext context) {
    final template = state.template;
    final sections = template.sectionOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < sections.length; i++)
          _SectionBlock(
            title: _sectionTitle(context, sections[i]),
            onMoveUp: i == 0
                ? null
                : () =>
                      cubit.update(template: template.moveSection(i, up: true)),
            onMoveDown: i == sections.length - 1
                ? null
                : () => cubit.update(
                    template: template.moveSection(i, up: false),
                  ),
            child: _sectionFields(context, sections[i]),
          ),
      ],
    );
  }

  String _sectionTitle(BuildContext context, ReceiptTemplateSection section) {
    final l10n = context.l10n;
    return switch (section) {
      ReceiptTemplateSection.header =>
        l10n.cafeConfigurationReceiptHeaderSection,
      ReceiptTemplateSection.orderInfo =>
        l10n.cafeConfigurationReceiptOrderInfoSection,
      ReceiptTemplateSection.items => l10n.cafeConfigurationReceiptItemsSection,
      ReceiptTemplateSection.totals =>
        l10n.cafeConfigurationReceiptTotalsSection,
      ReceiptTemplateSection.payment =>
        l10n.cafeConfigurationReceiptPaymentSection,
      ReceiptTemplateSection.footer =>
        l10n.cafeConfigurationReceiptFooterSection,
    };
  }

  Widget _sectionFields(BuildContext context, ReceiptTemplateSection section) {
    final l10n = context.l10n;
    final template = state.template;
    switch (section) {
      case ReceiptTemplateSection.header:
        final header = template.header;
        return Column(
          children: <Widget>[
            _toggle(
              key: 'receipt-header-logo',
              label: l10n.cafeConfigurationReceiptHeaderLogo,
              value: header.showLogo,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  header: header.copyWith(showLogo: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-header-cafeName',
              label: l10n.cafeConfigurationReceiptHeaderCafeName,
              value: header.showCafeName,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  header: header.copyWith(showCafeName: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-header-branchName',
              label: l10n.cafeConfigurationReceiptHeaderBranchName,
              value: header.showBranchName,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  header: header.copyWith(showBranchName: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-header-address',
              label: l10n.cafeConfigurationReceiptHeaderAddress,
              value: header.showAddress,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  header: header.copyWith(showAddress: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-header-phone',
              label: l10n.cafeConfigurationReceiptHeaderPhone,
              value: header.showPhone,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  header: header.copyWith(showPhone: v),
                ),
              ),
            ),
          ],
        );
      case ReceiptTemplateSection.orderInfo:
        final info = template.orderInfo;
        return Column(
          children: <Widget>[
            _toggle(
              key: 'receipt-orderInfo-orderNumber',
              label: l10n.cafeConfigurationReceiptOrderNumber,
              value: info.showOrderNumber,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  orderInfo: info.copyWith(showOrderNumber: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-orderInfo-dateTime',
              label: l10n.cafeConfigurationReceiptDateTime,
              value: info.showDateTime,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  orderInfo: info.copyWith(showDateTime: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-orderInfo-cashier',
              label: l10n.cafeConfigurationReceiptCashier,
              value: info.showCashier,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  orderInfo: info.copyWith(showCashier: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-orderInfo-customer',
              label: l10n.cafeConfigurationReceiptCustomer,
              value: info.showCustomer,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  orderInfo: info.copyWith(showCustomer: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-orderInfo-orderType',
              label: l10n.cafeConfigurationReceiptOrderType,
              value: info.showOrderType,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  orderInfo: info.copyWith(showOrderType: v),
                ),
              ),
            ),
          ],
        );
      case ReceiptTemplateSection.items:
        final items = template.items;
        return Column(
          children: <Widget>[
            _toggle(
              key: 'receipt-items-productName',
              label: l10n.cafeConfigurationReceiptProductName,
              value: true,
              locked: true,
              onChanged: null,
            ),
            _toggle(
              key: 'receipt-items-quantity',
              label: l10n.cafeConfigurationReceiptQuantity,
              value: items.showQuantity,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  items: items.copyWith(showQuantity: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-items-unitPrice',
              label: l10n.cafeConfigurationReceiptUnitPrice,
              value: items.showUnitPrice,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  items: items.copyWith(showUnitPrice: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-items-modifiers',
              label: l10n.cafeConfigurationReceiptModifiers,
              value: items.showModifiers,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  items: items.copyWith(showModifiers: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-items-notes',
              label: l10n.cafeConfigurationReceiptNotes,
              value: items.showNotes,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  items: items.copyWith(showNotes: v),
                ),
              ),
            ),
          ],
        );
      case ReceiptTemplateSection.totals:
        final totals = template.totals;
        return Column(
          children: <Widget>[
            _toggle(
              key: 'receipt-totals-subtotal',
              label: l10n.cafeConfigurationReceiptSubtotal,
              value: totals.showSubtotal,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  totals: totals.copyWith(showSubtotal: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-totals-discount',
              label: l10n.cafeConfigurationReceiptDiscount,
              value: totals.showDiscount,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  totals: totals.copyWith(showDiscount: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-totals-tax',
              label: l10n.cafeConfigurationReceiptTax,
              value: totals.showTax,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  totals: totals.copyWith(showTax: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-totals-total',
              label: l10n.cafeConfigurationReceiptTotal,
              value: true,
              locked: true,
              onChanged: null,
            ),
          ],
        );
      case ReceiptTemplateSection.payment:
        final payment = template.payment;
        return Column(
          children: <Widget>[
            _toggle(
              key: 'receipt-payment-method',
              label: l10n.cafeConfigurationReceiptPaymentMethod,
              value: payment.showPaymentMethod,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  payment: payment.copyWith(showPaymentMethod: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-payment-paid',
              label: l10n.cafeConfigurationReceiptPaidAmount,
              value: payment.showPaidAmount,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  payment: payment.copyWith(showPaidAmount: v),
                ),
              ),
            ),
            _toggle(
              key: 'receipt-payment-change',
              label: l10n.cafeConfigurationReceiptChange,
              value: payment.showChange,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  payment: payment.copyWith(showChange: v),
                ),
              ),
            ),
          ],
        );
      case ReceiptTemplateSection.footer:
        final footer = template.footer;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _toggle(
              key: 'receipt-footer-enabled',
              label: l10n.cafeConfigurationReceiptFooterEnabled,
              value: footer.enabled,
              onChanged: (v) => cubit.update(
                template: template.copyWith(
                  footer: footer.copyWith(enabled: v),
                ),
              ),
            ),
            if (footer.enabled)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TextFormField(
                  key: ValueKey(
                    'receipt-footer-text-${state.selectedBranchId}-${state.formVersion}',
                  ),
                  initialValue: footer.text,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: l10n.cafeConfigurationReceiptFooterText,
                  ),
                  onChanged: (v) => cubit.update(
                    template: template.copyWith(
                      footer: footer.copyWith(text: v),
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _toggle({
    required String key,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool locked = false,
  }) => Material(
    color: AppColors.transparent,
    child: CheckboxListTile(
      key: Key(key),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      value: value,
      onChanged: locked ? null : (v) => onChanged?.call(v ?? value),
      title: Text(label),
    ),
  );
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.title,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.child,
  });

  final String title;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: l10n.cafeConfigurationReceiptMoveUp,
                icon: const Icon(Icons.arrow_upward),
                onPressed: onMoveUp,
              ),
              IconButton(
                tooltip: l10n.cafeConfigurationReceiptMoveDown,
                icon: const Icon(Icons.arrow_downward),
                onPressed: onMoveDown,
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}
