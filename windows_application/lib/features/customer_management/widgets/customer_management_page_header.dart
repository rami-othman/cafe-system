import 'package:flutter/material.dart';

import 'customer_management_visual_tokens.dart';

class CustomerManagementPageHeader extends StatelessWidget {
  const CustomerManagementPageHeader({
    super.key,
    required this.title,
    required this.description,
    this.breadcrumbs = const <String>[],
    this.identity,
    this.status,
    this.primaryAction,
    this.secondaryAction,
    this.actions,
  });

  final String title;
  final String description;
  final List<String> breadcrumbs;
  final Widget? identity;
  final Widget? status;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool narrow = constraints.maxWidth < 640;
      final Widget heading = _Heading(
        title: title,
        description: description,
        breadcrumbs: breadcrumbs,
        identity: identity,
        status: status,
      );
      final List<Widget> actionWidgets = <Widget>[
        ?secondaryAction,
        ?primaryAction,
        ?actions,
      ];
      final Widget actionsSlot = actionWidgets.isEmpty
          ? const SizedBox.shrink()
          : Align(
              alignment: AlignmentDirectional.topStart,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: actionWidgets,
              ),
            );

      return Semantics(
        container: true,
        header: true,
        label: title,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 20),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[heading, actionsSlot],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: Directionality.of(context),
                  children: <Widget>[
                    Expanded(child: heading),
                    if (actionWidgets.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 20),
                      Flexible(child: actionsSlot),
                    ],
                  ],
                ),
        ),
      );
    },
  );
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.title,
    required this.description,
    required this.breadcrumbs,
    this.identity,
    this.status,
  });

  final String title;
  final String description;
  final List<String> breadcrumbs;
  final Widget? identity;
  final Widget? status;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      if (breadcrumbs.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            for (final String breadcrumb in breadcrumbs)
              Text(
                breadcrumb,
                style: CustomerManagementVisualTokens.pageDescription,
              ),
          ],
        ),
      if (breadcrumbs.isNotEmpty) const SizedBox(height: 8),
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget titleWidget = ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : double.infinity,
            ),
            child: Text(
              title,
              key: const ValueKey<String>('customer-management-page-title'),
              overflow: TextOverflow.ellipsis,
              style: CustomerManagementVisualTokens.pageTitle,
            ),
          );
          final List<Widget> identityWidgets = <Widget>[
            titleWidget,
            if (identity != null) ...<Widget>[
              const SizedBox(width: 8),
              identity!,
            ],
            if (status != null) ...<Widget>[const SizedBox(width: 8), status!],
          ];
          return constraints.maxWidth < 520
              ? Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: identityWidgets,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: identityWidgets,
                );
        },
      ),
      if (description.isNotEmpty) ...<Widget>[
        const SizedBox(height: 6),
        Text(
          description,
          key: const ValueKey<String>('customer-management-page-description'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: CustomerManagementVisualTokens.pageDescription,
        ),
      ],
    ],
  );
}
