import 'package:flutter/material.dart';

import '../../../shared/layouts/desktop_page_layout.dart';
import '../widgets/pos_product_area.dart';

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DesktopPageLayout(child: PosProductArea());
  }
}
