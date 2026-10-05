import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../app/localization/localization_extensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../controllers/orders_state.dart';
import '../models/order_payment_summary.dart';
import '../models/order_status.dart';
import '../models/order_type.dart';
import '../models/refund_reason.dart';
import '../models/refund_type.dart';

/// Localization for the orders feature.
///
/// The orders cubit, repository and models keep stable English values (they are
/// compared in logic, tests and sent to the backend). These helpers translate
/// them only at display time.
extension OrdersL10nContext on BuildContext {
  /// Falls back to English when no localization delegate is installed so
  /// isolated widgets and tests keep their established English text.
  AppLocalizations get ordersL10n => maybeL10n ?? AppLocalizationsEn();
}

String ordersStatusLabel(AppLocalizations l, OrderStatus status) {
  return switch (status) {
    OrderStatus.preparing => l.ordersStatusPreparing,
    OrderStatus.held => l.ordersStatusHeld,
    OrderStatus.ready => l.ordersStatusReady,
    OrderStatus.paid => l.ordersStatusPaid,
    OrderStatus.completed => l.ordersStatusCompleted,
    OrderStatus.cancelled => l.ordersStatusCancelled,
    OrderStatus.refunded => l.ordersStatusRefunded,
    OrderStatus.partiallyRefunded => l.ordersStatusPartiallyRefunded,
  };
}

String ordersTypeLabel(AppLocalizations l, OrderSummaryType type) {
  return switch (type) {
    OrderSummaryType.dineIn => l.posOrderTypeDineIn,
    OrderSummaryType.takeaway => l.posOrderTypeTakeaway,
    OrderSummaryType.delivery => l.posOrderTypeDelivery,
  };
}

String ordersFilterLabel(AppLocalizations l, OrdersFilter filter) {
  return switch (filter) {
    OrdersFilter.activeOrders => l.ordersFilterActive,
    OrdersFilter.heldOrders => l.ordersFilterHeld,
    OrdersFilter.dineIn => l.ordersFilterDineIn,
    OrdersFilter.takeaway => l.ordersFilterTakeaway,
  };
}

String ordersRefundReasonLabel(AppLocalizations l, RefundReason reason) {
  return switch (reason) {
    RefundReason.customerRequest => l.ordersRefundReasonCustomerRequest,
    RefundReason.wrongItem => l.ordersRefundReasonWrongItem,
    RefundReason.itemQualityIssue => l.ordersRefundReasonQuality,
    RefundReason.duplicateCharge => l.ordersRefundReasonDuplicate,
    RefundReason.orderCancelled => l.ordersRefundReasonOrderCancelled,
    RefundReason.managerApproved => l.ordersRefundReasonManagerApproved,
    RefundReason.other => l.ordersRefundReasonOther,
  };
}

String ordersRefundTypeLabel(AppLocalizations l, RefundType type) {
  return switch (type) {
    RefundType.full => l.ordersRefundTypeFull,
    RefundType.partial => l.ordersRefundTypePartial,
  };
}

/// Translates the relative time produced by the repository
/// ("Just now", "5m ago", "2h ago", "3d ago").
String ordersTimeAgo(AppLocalizations l, String value) {
  final String trimmed = value.trim();
  if (trimmed == 'Just now') {
    return l.ordersJustNow;
  }
  final RegExpMatch? match = RegExp(r'^(\d+)([mhd]) ago$').firstMatch(trimmed);
  if (match == null) {
    return value;
  }
  final String amount = match.group(1)!;
  return switch (match.group(2)) {
    'm' => l.ordersMinutesAgo(amount),
    'h' => l.ordersHoursAgo(amount),
    _ => l.ordersDaysAgo(amount),
  };
}

String ordersCustomerName(AppLocalizations l, String name) {
  return switch (name.trim()) {
    'Walk-in' => l.ordersWalkIn,
    'Walk-in Customer' => l.ordersWalkInCustomer,
    _ => name,
  };
}

String ordersItemName(AppLocalizations l, String name) {
  return name == 'Item' ? l.ordersItemFallback : name;
}

String ordersModifierLabel(AppLocalizations l, String modifier) {
  const String notePrefix = 'Note: ';
  if (modifier.startsWith(notePrefix)) {
    return l.ordersNote(modifier.substring(notePrefix.length));
  }
  return modifier;
}

String ordersPaymentMethodLabel(AppLocalizations l, OrderPaymentSummary payment) {
  if (!payment.hasPayment && payment.methodLabel == 'No payment recorded yet.') {
    return l.ordersNoPaymentYet;
  }
  return switch ((payment.method ?? '').trim().toLowerCase()) {
    'cash' => l.posPaymentMethodCash,
    'card' => l.posPaymentMethodCard,
    'wallet' => l.ordersMethodWallet,
    'sham_cash' => l.ordersMethodShamCash,
    'split' => l.ordersMethodSplit,
    _ => payment.methodLabel,
  };
}

String ordersPaymentStatusLabel(AppLocalizations l, String statusLabel) {
  return switch (statusLabel.trim().toLowerCase()) {
    'pending' => l.ordersPaymentStatusPending,
    'completed' => l.ordersPaymentStatusCompleted,
    'failed' => l.ordersPaymentStatusFailed,
    'approved' => l.ordersPaymentStatusApproved,
    'voided' => l.ordersPaymentStatusVoided,
    'refunded' => l.ordersPaymentStatusRefunded,
    _ => statusLabel,
  };
}

String ordersTimelineTitle(AppLocalizations l, String title) {
  return switch (title.trim().toLowerCase()) {
    'order created' => l.ordersEventCreated,
    'order held' => l.ordersEventHeld,
    'order closed' => l.ordersEventClosed,
    'refund completed' => l.ordersEventRefundCompleted,
    'payment received' => l.ordersEventPaymentReceived,
    'order completed' => l.ordersEventCompleted,
    'order ready' => l.ordersEventReady,
    'order preparing' => l.ordersEventPreparing,
    _ => title,
  };
}

String ordersTimelineSubtitle(AppLocalizations l, String subtitle) {
  return subtitle == 'Backend event' ? l.ordersBackendEvent : subtitle;
}

/// Latin digits, matching the rest of the application.
String ordersFormatDate(DateTime value) {
  return DateFormat('dd/MM/yyyy', 'en').format(value);
}

String ordersFormatTime(AppLocalizations l, DateTime value) {
  final int hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? l.ordersAm : l.ordersPm}';
}

/// Translates the known English messages produced by the orders cubit.
/// Messages coming from the backend (or unknown ones) are returned unchanged.
String localizeOrdersMessage(AppLocalizations l, String message) {
  return switch (message.trim()) {
    'No active branches are available.' => l.ordersMsgNoActiveBranches,
    'Order page recovery returned invalid pagination metadata.' => l.ordersMsgPageRecoveryInvalid,
    'Could not load orders. Check backend connection.' => l.ordersMsgLoadFailed,
    'Could not load order details. Check backend connection.' => l.ordersMsgDetailsLoadFailed,
    'This order cannot be resumed because its backend id is invalid.' => l.ordersMsgResumeInvalidId,
    'The backend returned a different order. Refresh and try again.' => l.ordersMsgDifferentOrder,
    'This order is not in the selected branch.' => l.ordersMsgNotInBranch,
    'Only an unpaid held order can be resumed.' => l.ordersMsgOnlyHeldResume,
    'Could not resume this order in POS. Please try again.' => l.ordersMsgResumeInPosFailed,
    'Could not resume this order. Check backend connection.' => l.ordersMsgResumeConnFailed,
    'This order cannot be cancelled because its backend id is invalid.' => l.ordersMsgCancelInvalidId,
    'Could not verify this order before cancellation.' => l.ordersMsgCancelVerifyFailed,
    'Only an unpaid draft or held order can be cancelled.' => l.ordersMsgOnlyDraftHeldCancel,
    'Could not cancel this order. No changes were confirmed.' => l.ordersMsgCancelNoChange,
    'Order id is not a backend id.' => l.ordersMsgOrderIdInvalid,
    'Could not prepare payment. Check order access and try again.' => l.ordersMsgPaymentPrepareAccess,
    'Payment is not ready. Refresh the order and try again.' => l.ordersMsgPaymentNotReady,
    'This order cannot be paid in its current state.' => l.ordersMsgCannotPayState,
    'Could not prepare payment. Please try again.' => l.ordersMsgPaymentPrepareFailed,
    'Payment requires an authenticated backend connection.' => l.ordersMsgPaymentNeedsBackend,
    'Could not record payment. Please try again.' => l.ordersMsgPaymentRecordFailed,
    'Payment was not completed. You can retry safely with the same operation.' => l.ordersMsgPaymentNotCompleted,
    'Payment completed, but the receipt could not be loaded.' => l.ordersMsgReceiptLoadFailed,
    'Payment summary did not match the selected order.' => l.ordersMsgPaymentSummaryMismatch,
    'No supported payment method is available for this order.' => l.ordersMsgNoSupportedMethod,
    'Payment status could not be confirmed. Check the order before retrying.' => l.ordersMsgPaymentUncertain,
    'This order has no completed payment or refundable balance.' => l.ordersMsgNoRefundable,
    'Could not prepare the refund. Please try again.' => l.ordersMsgRefundPrepareFailed,
    'Could not record the refund. Please try again.' => l.ordersMsgRefundRecordFailed,
    'Refund was not found on the server. Check the order, then retry with the same operation.' => l.ordersMsgRefundNotFound,
    'Refund status could not be confirmed. Check the order before retrying.' => l.ordersMsgRefundUncertain,
    'Cancellation status could not be confirmed. Check status before retrying.' => l.ordersMsgCancelUncertain,
    'Cancellation status is unresolved. Check status before retrying.' => l.ordersMsgCancelUnresolved,
    'Order is still active and unpaid. Check status, then retry cancellation explicitly.' => l.ordersMsgStillActive,
    _ => message,
  };
}
