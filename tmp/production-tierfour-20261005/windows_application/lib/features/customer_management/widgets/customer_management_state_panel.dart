import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/customer_failure.dart';
import 'customer_management_surface.dart';
import 'customer_management_visual_tokens.dart';

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
    this.collectionSurface = false,
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
  final bool collectionSurface;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (failure == null && !empty && !noResults) {
      final Widget skeleton = Semantics(
        container: true,
        liveRegion: true,
        label: l10n.cmvpStateLoadingSemantics,
        child: _LoadingSkeleton(geometry: loadingGeometry),
      );
      return collectionSurface &&
              loadingGeometry == CustomerManagementLoadingGeometry.collection
          ? Align(alignment: AlignmentDirectional.topCenter, child: skeleton)
          : skeleton;
    }

    final _StateCopy copy = _stateCopy(l10n, collection: collectionSurface);
    final Widget content = Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(copy.icon, size: collectionSurface ? 30 : 32, color: copy.color),
          const SizedBox(height: 12),
          Text(
            copy.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CustomerManagementVisualTokens.rowText,
              fontSize: collectionSurface ? 15 : null,
              fontWeight: collectionSurface ? FontWeight.w700 : null,
              fontFamilyFallback:
                  CustomerManagementVisualTokens.fontFamilyFallback,
            ),
          ),
          if (copy.message != null) ...<Widget>[
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                copy.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CustomerManagementVisualTokens.mutedText,
                  fontSize: 13,
                  fontFamilyFallback:
                      CustomerManagementVisualTokens.fontFamilyFallback,
                ),
              ),
            ),
          ],
          if (empty && onCreate != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onCreate,
              style: _primaryButtonStyle,
              child: Text(
                onCreateLabel ?? l10n.customerManagementCreateCustomer,
              ),
            ),
          ],
          if (noResults && onClear != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                foregroundColor: CustomerManagementVisualTokens.accent,
                side: const BorderSide(
                  color: CustomerManagementVisualTokens.border,
                ),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
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
              style: _primaryButtonStyle,
              child: Text(l10n.customerManagementRetry),
            ),
          ],
        ],
      ),
    );

    if (!collectionSurface) return Center(child: content);
    final double minHeight = empty ? 264 : 214;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double panelHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - 2).clamp(0, minHeight).toDouble()
            : minHeight;
        return Align(
          alignment: AlignmentDirectional.topCenter,
          child: CustomerManagementSurface(
            body: SizedBox(
              height: panelHeight,
              child: Center(child: content),
            ),
          ),
        );
      },
    );
  }

  _StateCopy _stateCopy(AppLocalizations l10n, {required bool collection}) {
    if (failure?.kind == CustomerFailureKind.forbidden) {
      return _StateCopy(
        icon: Icons.block_outlined,
        title: l10n.cmvpForbiddenTitle,
        message: l10n.cmvpForbiddenMessage,
        color: CustomerManagementVisualTokens.mutedText,
      );
    }
    if (failure?.kind == CustomerFailureKind.notFound) {
      return _StateCopy(
        icon: Icons.search_off_outlined,
        title: l10n.cmvpNotFoundTitle,
        message: l10n.cmvpNotFoundMessage,
        color: CustomerManagementVisualTokens.mutedText,
      );
    }
    if (failure?.kind == CustomerFailureKind.validation) {
      return _StateCopy(
        icon: Icons.error_outline,
        title: l10n.customerManagementValidationFailed,
        color: CustomerManagementVisualTokens.accent,
      );
    }
    if (noResults) {
      return _StateCopy(
        icon: Icons.search_off_outlined,
        title: l10n.cmvpNoResultsTitle,
        message: collection
            ? l10n.cmvpNoResultsMessage
            : l10n.customerManagementNoResults,
        color: CustomerManagementVisualTokens.mutedText,
      );
    }
    if (empty) {
      return _StateCopy(
        icon: Icons.inbox_outlined,
        title: collection
            ? l10n.customerManagementEmptyCustomers
            : l10n.cmvpEmptyTitle,
        message: collection
            ? l10n.cmvpEmptyCustomersMessage
            : emptyMessage ?? l10n.customerManagementEmptyCustomers,
        color: CustomerManagementVisualTokens.mutedText,
      );
    }
    return _StateCopy(
      icon: Icons.warning_amber_outlined,
      title: collection
          ? l10n.customerManagementRequestFailed
          : l10n.cmvpRetryableTitle,
      message: collection
          ? l10n.cmvpRetryableMessage
          : l10n.customerManagementRequestFailed,
      color: collection
          ? CustomerManagementVisualTokens.error
          : CustomerManagementVisualTokens.accent,
    );
  }
}

const ButtonStyle _primaryButtonStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size(0, 38)),
  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: 18),
  ),
  backgroundColor: WidgetStatePropertyAll<Color>(
    CustomerManagementVisualTokens.accent,
  ),
  foregroundColor: WidgetStatePropertyAll<Color>(Colors.white),
  shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
  ),
);

class _StateCopy {
  const _StateCopy({
    required this.icon,
    required this.title,
    required this.color,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.geometry});

  final CustomerManagementLoadingGeometry geometry;

  @override
  Widget build(BuildContext context) {
    if (geometry == CustomerManagementLoadingGeometry.collection) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool useCards =
              CustomerManagementVisualTokens.usesCollectionCards(
                constraints.maxWidth,
              );
          final int count = 6;
          final double rowHeight = useCards ? 84 : 58;
          final double desiredHeight = 42 + count * rowHeight;
          final double surfaceHeight = constraints.maxHeight.isFinite
              ? (constraints.maxHeight - 2).clamp(0, desiredHeight).toDouble()
              : desiredHeight;
          return KeyedSubtree(
            key: const Key('customer-management-loading-skeleton'),
            child: CustomerManagementSurface(
              body: SizedBox(
                height: surfaceHeight,
                child: Column(
                  children: <Widget>[
                    const SizedBox(
                      height: 42,
                      child: ColoredBox(
                        color: CustomerManagementVisualTokens.warmHeader,
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: count,
                        separatorBuilder: (_, _) => const SizedBox(height: 0),
                        itemBuilder: (_, _) => _SkeletonRow(useCards: useCards),
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

    final int count = switch (geometry) {
      CustomerManagementLoadingGeometry.detail => 3,
      CustomerManagementLoadingGeometry.form => 4,
      CustomerManagementLoadingGeometry.dialog => 3,
      CustomerManagementLoadingGeometry.collection => 6,
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
                          color: CustomerManagementVisualTokens.skeleton,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.useCards});

  final bool useCards;

  @override
  Widget build(BuildContext context) {
    final Widget bars = Row(
      children: <Widget>[
        Container(
          width: useCards ? 96 : 160,
          height: 12,
          decoration: BoxDecoration(
            color: CustomerManagementVisualTokens.skeleton,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const Spacer(),
        Container(
          width: useCards ? 120 : 80,
          height: 12,
          decoration: BoxDecoration(
            color: CustomerManagementVisualTokens.skeleton,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
    return Container(
      height: useCards ? 84 : 58,
      padding: EdgeInsets.symmetric(horizontal: useCards ? 12 : 20),
      decoration: BoxDecoration(
        color: CustomerManagementVisualTokens.surface,
        border: const Border(
          bottom: BorderSide(color: CustomerManagementVisualTokens.border),
        ),
      ),
      child: useCards
          ? Center(child: bars)
          : Align(alignment: AlignmentDirectional.center, child: bars),
    );
  }
}
