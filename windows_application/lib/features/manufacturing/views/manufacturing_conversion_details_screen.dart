import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/management_ui.dart';
import '../controllers/manufacturing_conversion_cubit.dart';
import '../controllers/manufacturing_conversion_state.dart';
import '../models/manufacturing_conversion_models.dart';

class ManufacturingConversionDetailsScreen extends StatefulWidget {
  const ManufacturingConversionDetailsScreen({
    super.key,
    required this.idOrReference,
  });
  final String idOrReference;

  @override
  State<ManufacturingConversionDetailsScreen> createState() =>
      _ManufacturingConversionDetailsScreenState();
}

class _ManufacturingConversionDetailsScreenState
    extends State<ManufacturingConversionDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final ManufacturingConversionCubit cubit = context
        .read<ManufacturingConversionCubit>();
    if (cubit.state.result?.id != widget.idOrReference) {
      Future<void>.microtask(() => cubit.loadConversion(widget.idOrReference));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ManufacturingConversionCubit, ManufacturingConversionState>(
    builder: (BuildContext context, ManufacturingConversionState state) {
      final ManufacturingConversionResult? result =
          state.result?.id == widget.idOrReference ? state.result : null;
      return SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const ManagementPageHeader(
              title: 'تفاصيل التحويل',
              subtitle: 'نتيجة عملية التحويل كما وردت من الخادم.',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (state.loading && result == null)
              const Padding(padding: AppSpacing.allXxl, child: AppLoading())
            else if (result == null)
              ManagementMessage(
                message: state.error ?? 'التحويل غير موجود.',
                error: true,
              )
            else
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(result.id, style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'المصدر: ${result.sourceItemName ?? result.sourceItemId} — ${result.sourceQty}',
                    ),
                    Text(
                      'الهدف: ${result.targetItemName ?? result.targetItemId} — ${result.resultQty}',
                    ),
                    if (result.resultUnitCost != null)
                      Text('تكلفة الوحدة الناتجة: ${result.resultUnitCost}'),
                    if (result.totalCost != null)
                      Text('التكلفة الإجمالية: ${result.totalCost}'),
                    if (result.date != null) Text('التاريخ: ${result.date}'),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
