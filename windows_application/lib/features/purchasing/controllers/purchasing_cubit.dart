import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:convert';
import '../../../core/network/api_exception.dart';

import '../repositories/purchasing_repository.dart';
import '../models/purchasing_models.dart';
import 'purchasing_state.dart';

class PurchasingCubit extends Cubit<PurchasingState> {
  PurchasingCubit({required this.repository}) : super(const PurchasingState());

  final PurchasingRepository repository;
  final Map<int, _ReceiptAttempt> _receipts = <int, _ReceiptAttempt>{};
  final Map<int, Future<PurchaseReceipt>> _receiving =
      <int, Future<PurchaseReceipt>>{};

  Future<PurchaseReceipt> receiveAndPost(
    int invoiceId,
    Map<String, dynamic> data,
  ) {
    return _receiving.putIfAbsent(
      invoiceId,
      () => _receiveAndPost(invoiceId, data).whenComplete(() {
        _receiving.remove(invoiceId);
      }),
    );
  }

  Future<PurchaseReceipt> _receiveAndPost(
    int invoiceId,
    Map<String, dynamic> data,
  ) async {
    final payload = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
    final attempt = _receipts.putIfAbsent(
      invoiceId,
      () => _ReceiptAttempt(payload),
    );
    // Reuse the original create payload after an uncertain response, even if
    // the form was edited. Resolve that receipt before changing its draft.
    late final PurchaseReceipt draft;
    try {
      draft = attempt.id == null
          ? await repository.createReceipt(invoiceId, <String, dynamic>{
              ...attempt.payload,
              'idempotencyKey': attempt.createKey,
            })
          : await repository.getReceipt(attempt.id!);
    } on ApiException catch (error) {
      // A rejected draft can be corrected; uncertain outcomes retain their keys.
      if (attempt.id == null && error.statusCode == 422) {
        _receipts.remove(invoiceId);
      }
      rethrow;
    }
    attempt.id = draft.id;
    if (draft.status == 'posted') {
      _receipts.remove(invoiceId);
      return draft;
    }
    if (jsonEncode(payload) != jsonEncode(attempt.payload)) {
      await repository.updateReceipt(draft.id, payload);
      attempt.payload = payload;
    }
    final posted = await repository.postReceipt(draft.id, attempt.postKey);
    _receipts.remove(invoiceId);
    return posted;
  }
}

class _ReceiptAttempt {
  _ReceiptAttempt(this.payload)
    : key = DateTime.now().microsecondsSinceEpoch.toString();
  Map<String, dynamic> payload;
  final String key;
  int? id;
  String get createKey => 'grn-create-$key';
  String get postKey => 'grn-post-$key';
}
