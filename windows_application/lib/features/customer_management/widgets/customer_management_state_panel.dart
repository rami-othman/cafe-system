import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_failure.dart';

enum CustomerManagementLoadingGeometry { collection, detail, form, dialog }

class CustomerManagementStatePanel extends StatelessWidget {
  const CustomerManagementStatePanel({
    super.key,
    this.failure,
    this.onRetry,
    this.onClear,
    this.onCreate,
    this.onCreateLabel,
    this.empty = false,
    this.noResults = false,
    this.emptyMessage,
    this.loadingGeometry = CustomerManagementLoadingGeometry.collection,
  });

  final CustomerFailure? failure;
  final VoidCallback? onRetry;
  final VoidCallback? onClear;
  final VoidCallback? onCreate;
  final String? onCreateLabel;
  final bool empty;
  final bool noResults;
  final String? emptyMessage;
  final CustomerManagementLoadingGeometry loadingGeometry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (failure == null && !empty && !noResults) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: l10n.cmvpStateLoadingSemantics,
        child: _LoadingSkeleton(geometry: loadingGeometry),
      );
    }
    final _StateCopy copy = _stateCopy(l10n);
    return Center(
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(copy.icon, size: 32),
            const SizedBox(height: 12),
            Text(copy.title, textAlign: TextAlign.center),
            if (copy.message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(copy.message!, textAlign: TextAlign.center),
            ],
            if (empty && onCreate != null) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onCreate,
                child: Text(
                  onCreateLabel ?? l10n.customerManagementCreateCustomer,
                ),
              ),
            ],
            if (noResults && onClear != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onClear,
                child: Text(l10n.customerManagementClearFilters),
              ),
            ],
            if (onRetry != null &&
                !empty &&
                !noResults &&
                failure?.kind != CustomerFailureKind.forbidden &&
                failure?.kind != CustomerFailureKind.notFound) ...<Widget>[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: Text(l10n.customerManagementRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StateCopy _stateCopy(AppLocalizations l10n) {
    if (failure?.kind == CustomerFailureKind.forbidden) {
      return _StateCopy(
        icon: Icons.block_outlined,
        title: l10n.cmvpForbiddenTitle,
        message: l10n.cmvpForbiddenMessage,
      );
    }
    if (failure?.kind == CustomerFailureKind.notFound) {
      return _StateCopy(
        icon: Icons.search_off_outlined,
        title: l10n.cmvpNotFoundTitle,
        message: l10n.cmvpNotFoundMessage,
      );
    }
    if (failure?.kind == CustomerFailureKind.validation) {
      return _StateCopy(
        icon: Icons.error_outline,
        title: l10n.customerManagementValidationFailed,
      );
    }
    if (noResults) {
      return _StateCopy(
        icon: Icons.search_off_outlined,
        title: l10n.cmvpNoResultsTitle,
        message: l10n.customerManagementNoResults,
      );
    }
    if (empty) {
      return _StateCopy(
        icon: Icons.inbox_outlined,
        title: l10n.cmvpEmptyTitle,
        message: emptyMessage ?? l10n.customerManagementEmptyCustomers,
      );
    }
    return _StateCopy(
      icon: Icons.warning_amber_outlined,
      title: l10n.cmvpRetryableTitle,
      message: l10n.customerManagementRequestFailed,
    );
  }
}

class _StateCopy {
  const _StateCopy({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.geometry});

  final CustomerManagementLoadingGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final int count = switch (geometry) {
      CustomerManagementLoadingGeometry.collection => 5,
      CustomerManagementLoadingGeometry.detail => 3,
      CustomerManagementLoadingGeometry.form => 4,
      CustomerManagementLoadingGeometry.dialog => 3,
    };
    return KeyedSubtree(
      key: const Key('customer-management-loading-skeleton'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(
            count,
            (int index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: geometry == CustomerManagementLoadingGeometry.form
                          ? 52
                          : 24,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  if (geometry ==
                      CustomerManagementLoadingGeometry.collection) ...<Widget>[
                    const SizedBox(width: 12),
                    const SizedBox(width: 64, height: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
