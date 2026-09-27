import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_spacing.dart';
import '../controllers/factory_currency_cubit.dart';
import '../models/factory_currency.dart';

class FactoryCurrencyField extends StatelessWidget {
  const FactoryCurrencyField({
    super.key,
    required this.branchId,
    required this.onChanged,
    this.initial,
    this.amount = 0,
  });
  final int branchId;
  final FactoryCurrencySelection? initial;
  final ValueChanged<FactoryCurrencySelection> onChanged;
  final double amount;
  @override
  Widget build(BuildContext context) => BlocProvider<FactoryCurrencyCubit>(
    create: (_) =>
        serviceLocator<FactoryCurrencyCubit>()..load(branchId, initial),
    child: BlocConsumer<FactoryCurrencyCubit, FactoryCurrencyState>(
      listener: (_, state) {
        if (state.loaded) onChanged(state.selection);
      },
      builder: (context, state) {
        if (!state.loaded) return const LinearProgressIndicator();
        final choice = state.selection;
        final cubit = context.read<FactoryCurrencyCubit>();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('عملة المستند — الحساب والتكلفة بالليرة السورية'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: choice.currency,
                      decoration: const InputDecoration(
                        labelText: 'عملة الإدخال',
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(
                          value: 'SYP',
                          child: Text('ليرة سورية SYP'),
                        ),
                        DropdownMenuItem(
                          value: 'USD',
                          child: Text('دولار أمريكي USD'),
                        ),
                      ],
                      onChanged: state.saving
                          ? null
                          : (value) => cubit.select(
                              FactoryCurrencySelection(
                                currency: value!,
                                rate: choice.rate,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      initialValue: choice.rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '1 دولار = كم ليرة سورية؟',
                      ),
                      onChanged: (value) => cubit.select(
                        FactoryCurrencySelection(
                          currency: choice.currency,
                          rate: value.trim(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (choice.currency == 'USD')
                Text(
                  '${amount.toStringAsFixed(2)} USD = ${(amount * choice.multiplier).toStringAsFixed(2)} SYP',
                ),
              TextButton.icon(
                onPressed: state.saving ? null : () => cubit.save(branchId),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('حفظ العملة وسعر الصرف كإعدادات المعمل'),
              ),
              if (state.message != null) Text(state.message!),
            ],
          ),
        );
      },
    ),
  );
}

class FactoryCurrencyDocument extends StatelessWidget {
  const FactoryCurrencyDocument({
    super.key,
    required this.snapshot,
    required this.baseAmount,
  });
  final Map<String, dynamic>? snapshot;
  final String baseAmount;
  @override
  Widget build(BuildContext context) {
    if (snapshot == null) return const SizedBox.shrink();
    final choice = FactoryCurrencySelection.fromSnapshot(snapshot);
    final total = double.tryParse(baseAmount) ?? 0;
    final originalAmount = (snapshot?['input'] as Map?)?['amount'];
    final displayAmount = originalAmount == null
        ? (choice.multiplier > 0 ? total / choice.multiplier : 0)
              .toStringAsFixed(2)
        : (double.tryParse('$originalAmount') ?? 0).toStringAsFixed(2);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'مبلغ المستند: $displayAmount ${choice.currency}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (choice.currency == 'USD')
              Text('سعر الصرف المحفوظ: 1 USD = ${choice.rate} SYP'),
            Text('المقابل المحاسبي: ${total.toStringAsFixed(2)} SYP'),
            const Text('الأرصدة والتكلفة والتخصيصات أدناه بالليرة السورية.'),
          ],
        ),
      ),
    );
  }
}
