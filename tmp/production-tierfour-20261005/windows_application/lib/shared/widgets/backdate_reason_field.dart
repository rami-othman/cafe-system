import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_text_field.dart';

/// Shown only when [documentDate] is strictly before today — mirrors the
/// backend's `App\Support\BackdatePolicy::reason()` (client decision
/// 2026-09-28, T7): any invoice/return may be backdated, provided a reason
/// is recorded. When hidden, nothing needs to be sent.
class BackdateReasonField extends StatelessWidget {
  const BackdateReasonField({
    super.key,
    required this.documentDate,
    required this.controller,
    this.errorText,
  });

  final DateTime documentDate;
  final TextEditingController controller;
  final String? errorText;

  static bool isRequired(DateTime documentDate) {
    final DateTime today = DateTime.now();
    final DateTime day = DateTime(
      documentDate.year,
      documentDate.month,
      documentDate.day,
    );
    final DateTime todayDay = DateTime(today.year, today.month, today.day);
    return day.isBefore(todayDay);
  }

  @override
  Widget build(BuildContext context) {
    if (!isRequired(documentDate)) return const SizedBox.shrink();
    final String formattedDate = DateFormat('yyyy-MM-dd').format(documentDate);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'الفاتورة والمواد والنقد ستُسجَّل بتاريخ $formattedDate',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.orange.shade800),
          ),
          const SizedBox(height: 4),
          AppTextField(
            controller: controller,
            label: 'سبب التاريخ السابق',
            maxLines: 2,
            errorText: errorText,
          ),
        ],
      ),
    );
  }
}
