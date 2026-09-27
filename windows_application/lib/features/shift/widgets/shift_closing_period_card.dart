import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../controllers/shift_closing_cubit.dart';
import '../models/shift_close_preview.dart';
import 'shift_design.dart';
import 'shift_format.dart';
import 'shift_primitives.dart';

class ShiftClosingPeriodCard extends StatelessWidget {
  const ShiftClosingPeriodCard({super.key, this.editable = true});

  final bool editable;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShiftClosingCubit>();
    final state = context.watch<ShiftClosingCubit>().state;
    final preview = state.preview;
    final String date =
        state.closingDate?.toIso8601String().substring(0, 10) ??
        'اليوم بتوقيت الفرع';
    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const ShiftSectionHeader(
            title: 'الفترة التي ستُغلق',
            icon: Icons.calendar_today_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          if (editable)
            OutlinedButton.icon(
              key: const Key('shift-closing-date'),
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('تاريخ نهاية الفترة: $date'),
              onPressed: state.isPreviewLoading || state.isSubmitting
                  ? null
                  : () async {
                      final today =
                          preview?.today ??
                          DateUtils.dateOnly(cubit.repository.now);
                      final first =
                          preview?.openingDate ??
                          DateUtils.dateOnly(state.snapshot!.identity.openedAt);
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: state.closingDate ?? today,
                        firstDate: first.isAfter(today) ? today : first,
                        lastDate: today,
                      );
                      if (selected != null && context.mounted) {
                        await cubit.selectClosingDate(selected);
                      }
                    },
            )
          else
            Text('نهاية الفترة: $date', style: ShiftText.bodyStrong),
          if (state.isPreviewLoading) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            const Text('جارٍ احتساب حركات الفترة والنقدية وجرد البار…'),
          ],
          if (preview != null && !state.isPreviewLoading) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'من ${preview.openingDate.toIso8601String().substring(0, 10)} حتى نهاية $date — ${preview.timezone}',
              style: ShiftText.body,
            ),
            if (preview.historical) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              ShiftNotice(
                tone: ShiftTone.accent,
                message: 'هذا الإغلاق يشمل حركات الفترة السابقة فقط.',
                detail: preview.willContinue
                    ? 'الحركات اللاحقة والطلبات المفتوحة ستبقى في وردية متابعة. أي تحويل نقدية سيُسجّل وقت تنفيذه الفعلي.'
                    : 'لا توجد حركات لاحقة تحتاج وردية متابعة.',
              ),
              const SizedBox(height: AppSpacing.md),
              ShiftKeyValueRow(
                label: 'النقدية المتوقعة بنهاية الفترة',
                value: ShiftFormat.money(preview.snapshot.drawer.expected),
              ),
              ShiftKeyValueRow(
                label: 'رصيد الصندوق الحالي',
                value: ShiftFormat.money(preview.currentLedgerCash),
              ),
              ShiftKeyValueRow(
                label: 'صافي الحركات النقدية اللاحقة',
                value: ShiftFormat.signedMoney(preview.laterNetCash),
              ),
              ShiftKeyValueRow(
                label: 'التحويل إلى وجهة الإغلاق الآن',
                value: ShiftFormat.money(preview.transferAmount),
              ),
              ShiftKeyValueRow(
                label: 'رصيد المتابعة بعد التحويل',
                value: ShiftFormat.money(preview.continuationCashAfterTransfer),
              ),
              if (editable) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _BasisPicker(
                  label: 'مصدر عدّ النقدية',
                  value: state.cashCountBasis,
                  onChanged: cubit.selectCashCountBasis,
                ),
                const SizedBox(height: AppSpacing.md),
                _BasisPicker(
                  label: 'مصدر جرد البار',
                  value: state.barCountBasis,
                  onChanged: cubit.selectBarCountBasis,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'العدّ الآن يعيد احتساب نهاية الفترة بطرح الحركات اللاحقة المسجّلة. لا يُعتبر عدًا فعليًا حصل بالتاريخ السابق.',
                ),
              ] else ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'النقدية: ${state.cashCountBasis == ShiftCountBasis.current ? "عدّ الآن وإعادة احتساب نهاية الفترة" : "عدّ محفوظ لنهاية الفترة"}',
                ),
                Text(
                  'البار: ${state.barCountBasis == ShiftCountBasis.current ? "عدّ الآن وإعادة احتساب نهاية الفترة" : "جرد محفوظ لنهاية الفترة"}',
                ),
              ],
            ],
            for (final String issue in preview.issues) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              ShiftNotice(message: issue, tone: ShiftTone.blocker),
            ],
          ],
          if (editable && !state.isPreviewLoading)
            TextButton.icon(
              onPressed: () => cubit.selectClosingDate(state.closingDate),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة تحميل المعاينة ومراجعة العد'),
            ),
        ],
      ),
    );
  }
}

class _BasisPicker extends StatelessWidget {
  const _BasisPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final ShiftCountBasis? value;
  final ValueChanged<ShiftCountBasis> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<ShiftCountBasis>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        hint: const Text('اختر مصدر العد'),
        items: const <DropdownMenuItem<ShiftCountBasis>>[
          DropdownMenuItem(
            value: ShiftCountBasis.periodRecorded,
            child: Text('عدّ محفوظ لنهاية الفترة السابقة'),
          ),
          DropdownMenuItem(
            value: ShiftCountBasis.current,
            child: Text('عدّ الصندوق أو البار الآن'),
          ),
        ],
        onChanged: (ShiftCountBasis? selected) {
          if (selected != null) onChanged(selected);
        },
      );
}
