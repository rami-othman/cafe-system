import 'package:flutter/material.dart';

import '../../../core/network/dio_api_client.dart';
import '../../../core/services/service_locator.dart';
import '../../auth/controllers/auth_session_cubit.dart';
import '../models/customer_models.dart';

/// محفظة العميل: رصيد الأموال المحتفظ بها له، وحد الائتمان الذي يحدده المالك
/// (كم يستطيع الدفع بالمحفظة بالسالب). الحد الافتراضي 0.
class CustomerWalletCard extends StatelessWidget {
  const CustomerWalletCard({super.key, required this.customer, required this.onSaved});

  final Customer customer;
  final VoidCallback onSaved;

  bool get _isOwner =>
      serviceLocator.isRegistered<AuthSessionCubit>() &&
      serviceLocator<AuthSessionCubit>().state.session?.user.role == 'owner';

  Future<void> _editLimit(BuildContext context) async {
    final TextEditingController controller = TextEditingController(
      text: customer.walletCreditLimit ?? '0.00',
    );
    String? error;
    bool saving = false;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: const Text('حد ائتمان المحفظة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('أقصى مبلغ يستطيع العميل الدفع به من المحفظة بالسالب (فوق رصيده).'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الحد (SYP)', helperText: '0 = غير محدود. رقم موجب = أقصى دين مسموح للعميل.'),
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        await serviceLocator<DioApiClient>().put(
                          'admin/customer-management/customers/${customer.id}/wallet-limit',
                          data: <String, dynamic>{'walletCreditLimit': controller.text.trim()},
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } catch (e) {
                        if (dialogContext.mounted) {
                          update(() {
                            error = '$e';
                            saving = false;
                          });
                        }
                      }
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved == true) onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final double balance = double.tryParse(customer.walletBalance ?? '0') ?? 0;
    final bool unlimited = (double.tryParse(customer.walletCreditLimit ?? '0') ?? 0) <= 0;
    final Color balanceColor = balance > 0
        ? Colors.green.shade700
        : balance < 0
            ? Colors.red.shade700
            : Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    Widget metric(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value == 'غير محدود' ? value : '$value SYP',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 8),
                const Expanded(child: Text('محفظة العميل', style: TextStyle(fontWeight: FontWeight.w700))),
                if (_isOwner)
                  TextButton.icon(
                    onPressed: () => _editLimit(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل الحد'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                metric('رصيد المحفظة', customer.walletBalance ?? '0.00', color: balanceColor),
                // حد الائتمان 0 = غير محدود.
                metric('حد الائتمان', unlimited ? 'غير محدود' : (customer.walletCreditLimit ?? '0.00')),
                metric('المتاح للدفع', unlimited ? 'غير محدود' : (customer.walletAvailable ?? '0.00')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
