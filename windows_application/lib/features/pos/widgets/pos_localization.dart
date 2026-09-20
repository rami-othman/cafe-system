import '../../../core/utils/currency_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../models/applied_discount.dart';
import '../models/order_type.dart';
import '../models/payment_method.dart';

extension PaymentMethodLocalization on PaymentMethod {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.posPaymentMethodCash,
    PaymentMethod.card => l10n.posPaymentMethodCard,
    PaymentMethod.wallet => l10n.posPaymentMethodWallet,
    PaymentMethod.split => l10n.posPaymentMethodSplit,
  };
}

extension OrderTypeLocalization on OrderType {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    OrderType.dineIn => l10n.posOrderTypeDineIn,
    OrderType.takeaway => l10n.posOrderTypeTakeaway,
    OrderType.delivery => l10n.posOrderTypeDelivery,
  };
}

extension AppliedDiscountLocalization on AppliedDiscount {
  String localizedDisplayLabel(AppLocalizations l10n) => switch (type) {
    AppliedDiscountType.percentage => l10n.discountPercentOff(
      value.toStringAsFixed(0),
    ),
    AppliedDiscountType.fixedAmount => '-${CurrencyFormatter.format(value)}',
  };
}

String localizedPosFailure(AppLocalizations l10n, Object? failure) {
  final String message = failure?.toString() ?? '';
  if (message.contains('MENU_VERSION_STALE')) return l10n.posMenuVersionStale;
  if (message.contains('NO_OPEN_SHIFT')) return l10n.posOpenShiftRequired;
  if (message.contains('ORDER_BRANCH_MISMATCH')) {
    return l10n.posOrderUnavailableForBranch;
  }
  if (message.contains('ORDER_NOT_RESUMABLE')) return l10n.posHeldOrderRequired;
  if (message == 'pos.holdRetryable') return localizedPosHoldRetryable(l10n);
  if (message == 'pos.holdUncertain') return localizedPosHoldUncertain(l10n);
  return l10n.posOperationFailed;
}

String localizedPosHoldSucceeded(AppLocalizations l10n) {
  return l10n.localeName.startsWith('ar')
      ? 'تم تعليق الطلب بنجاح.'
      : 'Order held successfully.';
}

String localizedPosHoldRetryable(AppLocalizations l10n) {
  return l10n.localeName.startsWith('ar')
      ? 'تعذر تعليق الطلب. ما زالت السلة متاحة لإعادة المحاولة.'
      : 'The order could not be held. Your cart is still available to retry.';
}

String localizedPosHoldUncertain(AppLocalizations l10n) {
  return l10n.localeName.startsWith('ar')
      ? 'تعذر تأكيد حالة تعليق الطلب. ما زالت السلة متاحة؛ تحقق من الطلبات قبل إعادة المحاولة.'
      : 'The hold status could not be confirmed. Your cart is still available; check Orders before retrying.';
}
