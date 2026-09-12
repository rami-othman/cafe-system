import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_models.dart';
import 'customer_management_visual_tokens.dart';

class CustomerPagination extends StatelessWidget {
  const CustomerPagination({
    super.key,
    required this.meta,
    required this.onPageChanged,
  });
  final CustomerPageMeta meta;
  final ValueChanged<int> onPageChanged;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      key: const Key('customer-management-pagination-footer'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: CustomerManagementVisualTokens.border),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: <Widget>[
          Text(l10n.customerManagementPage(meta.currentPage, meta.lastPage)),
          IconButton(
            onPressed: meta.currentPage > 1
                ? () => onPageChanged(meta.currentPage - 1)
                : null,
            tooltip: l10n.customerManagementPreviousPage,
            icon: Icon(isRtl ? Icons.chevron_right : Icons.chevron_left),
          ),
          IconButton(
            onPressed: meta.currentPage < meta.lastPage
                ? () => onPageChanged(meta.currentPage + 1)
                : null,
            tooltip: l10n.customerManagementNextPage,
            icon: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
