import 'package:equatable/equatable.dart';
import 'discount_engine.dart';

class DiscountWorkspace extends Equatable {
  const DiscountWorkspace({
    this.capabilities,
    this.saved,
    this.review,
    this.quote,
    this.paymentMethods = const [],
    this.busy = false,
    this.totalsResolved = false,
    this.operationId,
    this.operationReviewId,
    this.operationUncertain = false,
    this.createUncertain = false,
    this.errorCode,
  });
  final DiscountCapabilities? capabilities;
  final SavedDiscountState? saved;
  final DiscountReview? review;
  final PaymentQuote? quote;
  final List<OperationalPaymentMethod> paymentMethods;
  final bool busy, totalsResolved, operationUncertain, createUncertain;
  final String? operationId, operationReviewId, errorCode;
  DiscountWorkspace copyWith({
    DiscountCapabilities? capabilities,
    SavedDiscountState? saved,
    DiscountReview? review,
    PaymentQuote? quote,
    List<OperationalPaymentMethod>? paymentMethods,
    bool? busy,
    bool? totalsResolved,
    bool? operationUncertain,
    bool? createUncertain,
    String? operationId,
    String? operationReviewId,
    String? errorCode,
    bool clearReview = false,
    bool clearQuote = false,
    bool clearOperation = false,
    bool clearError = false,
  }) => DiscountWorkspace(
    capabilities: capabilities ?? this.capabilities,
    saved: saved ?? this.saved,
    review: clearReview ? null : review ?? this.review,
    quote: clearQuote ? null : quote ?? this.quote,
    paymentMethods: paymentMethods ?? this.paymentMethods,
    busy: busy ?? this.busy,
    totalsResolved: totalsResolved ?? this.totalsResolved,
    createUncertain: createUncertain ?? this.createUncertain,
    operationUncertain: clearOperation
        ? false
        : operationUncertain ?? this.operationUncertain,
    operationId: clearOperation ? null : operationId ?? this.operationId,
    operationReviewId: clearOperation
        ? null
        : operationReviewId ?? this.operationReviewId,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
  );
  @override
  List<Object?> get props => [
    capabilities,
    saved,
    review,
    quote,
    paymentMethods,
    busy,
    totalsResolved,
    operationId,
    operationReviewId,
    operationUncertain,
    createUncertain,
    errorCode,
  ];
}
