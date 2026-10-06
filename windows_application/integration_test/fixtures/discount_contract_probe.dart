import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Assert protocol metadata without retaining tokens, bodies or coupon input.
void verifyDiscountRequestContract(RequestOptions request) {
  if (request.path.startsWith('orders')) {
    // Dio completion handlers can run while a widget pump is awaited in a
    // different zone. The SDK's callback-safe assertion retains the same
    // matcher without turning TestAsyncUtils.guardSync into a transport error.
    expectSync(request.headers['X-Discount-Contract'], '2');
  }
}
