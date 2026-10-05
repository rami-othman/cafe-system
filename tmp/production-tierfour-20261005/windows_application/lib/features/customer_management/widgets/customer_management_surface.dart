import 'package:flutter/material.dart';

import 'customer_management_visual_tokens.dart';

class CustomerManagementSurface extends StatelessWidget {
  const CustomerManagementSurface({
    super.key,
    this.header,
    required this.body,
    this.footer,
    this.readable = false,
    this.expandBody = false,
  });

  final Widget? header;
  final Widget body;
  final Widget? footer;
  final bool readable;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    final Widget surface = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: CustomerManagementVisualTokens.surface,
        border: Border.fromBorderSide(
          CustomerManagementVisualTokens.surfaceBorder,
        ),
        borderRadius: CustomerManagementVisualTokens.surfaceRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (header != null)
            Container(
              color: CustomerManagementVisualTokens.warmHeader,
              padding: CustomerManagementVisualTokens.surfacePadding,
              child: header,
            ),
          if (expandBody) Expanded(child: body) else body,
          if (footer != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: CustomerManagementVisualTokens.border),
                ),
              ),
              padding: CustomerManagementVisualTokens.surfacePadding,
              child: footer,
            ),
        ],
      ),
    );
    return readable
        ? Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: CustomerManagementVisualTokens.readableContentWidth,
              ),
              child: surface,
            ),
          )
        : surface;
  }
}
