import '../../../core/network/dio_api_client.dart';
import '../../finance_inventory_setup/widgets/finance_pagination.dart';
import '../../pos/models/json_helpers.dart';
import '../models/purchasing_models.dart';

/// Reads the Purchasing Center (`finance/purchases*`) and writes through the
/// pre-existing Supplier Invoice endpoints (`finance/supplier-invoices*`).
/// Purchasing intentionally has no create/post/reverse endpoint of its own —
/// a Purchase Invoice IS a Supplier Invoice, so every mutation must keep
/// going through the one AP domain that already owns posting, idempotency,
/// and reversal, per the approved architecture decision (no parallel
/// Purchase Invoice source of truth).
class PurchasingRepository {
  const PurchasingRepository(this._api);
  final DioApiClient _api;

  Future<FinancePage<PurchaseInvoice>> getPurchases({
    Map<String, dynamic>? queryParameters,
  }) async {
    final Map<String, dynamic> response = Map<String, dynamic>.from(
      await _api.getEnvelope(
            'finance/purchases',
            queryParameters: queryParameters,
          )
          as Map,
    );
    final List<Map<String, dynamic>> rows = readMapList(response['data']);
    final Map<String, dynamic>? meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : null;
    return FinancePage<PurchaseInvoice>(
      items: rows.map(PurchaseInvoice.fromJson).toList(growable: false),
      meta: FinancePageMeta.fromJson(meta, total: rows.length),
    );
  }

  Future<PurchaseInvoice> getPurchase(int id) async => PurchaseInvoice.fromJson(
    Map<String, dynamic>.from(await _api.get('finance/purchases/$id') as Map),
  );

  Future<PurchaseInvoice> savePurchase(
    Map<String, dynamic> payload, {
    int? id,
  }) async => PurchaseInvoice.fromJson(
    Map<String, dynamic>.from(
      (id == null
              ? await _api.post('finance/supplier-invoices', data: payload)
              : await _api.patch(
                  'finance/supplier-invoices/$id',
                  data: payload,
                ))
          as Map,
    ),
  );

  Future<PurchaseInvoice> postPurchase(
    int id,
    String idempotencyKey,
  ) async => PurchaseInvoice.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            'finance/supplier-invoices/$id/post',
            data: <String, dynamic>{'idempotencyKey': idempotencyKey},
          )
          as Map,
    ),
  );

  Future<PurchaseInvoice> reversePurchase(int id) async =>
      PurchaseInvoice.fromJson(
        Map<String, dynamic>.from(
          await _api.post('finance/supplier-invoices/$id/reverse') as Map,
        ),
      );

  // --- Goods Receipt (Phase 2) -----------------------------------------
  //
  // A Goods Receipt is an independent record from the Supplier Invoice — it
  // never mutates AP/payment state. It moves through
  // `finance/purchases/{invoice}/receipts` (create, and history for one
  // invoice) and `finance/purchase-receipts*` (a tenant-wide resource, used
  // by both the invoice detail screen and the "الاستلامات" list).

  Future<List<PurchaseReceiptSummary>> getReceiptsForInvoice(
    int invoiceId,
  ) async {
    final Map<String, dynamic> response = Map<String, dynamic>.from(
      await _api.getEnvelope('finance/purchases/$invoiceId/receipts') as Map,
    );

    return readMapList(
      response['data'],
    ).map(PurchaseReceiptSummary.fromJson).toList(growable: false);
  }

  Future<FinancePage<PurchaseReceipt>> getReceipts({
    Map<String, dynamic>? queryParameters,
  }) async {
    final Map<String, dynamic> response = Map<String, dynamic>.from(
      await _api.getEnvelope(
            'finance/purchase-receipts',
            queryParameters: queryParameters,
          )
          as Map,
    );
    final List<Map<String, dynamic>> rows = readMapList(response['data']);
    final Map<String, dynamic>? meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : null;
    return FinancePage<PurchaseReceipt>(
      items: rows.map(PurchaseReceipt.fromJson).toList(growable: false),
      meta: FinancePageMeta.fromJson(meta, total: rows.length),
    );
  }

  Future<PurchaseReceipt> getReceipt(int id) async => PurchaseReceipt.fromJson(
    Map<String, dynamic>.from(
      await _api.get('finance/purchase-receipts/$id') as Map,
    ),
  );

  Future<PurchaseReceipt> createReceipt(
    int invoiceId,
    Map<String, dynamic> payload,
  ) async => PurchaseReceipt.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            'finance/purchases/$invoiceId/receipts',
            data: payload,
          )
          as Map,
    ),
  );

  Future<PurchaseReceipt> updateReceipt(
    int receiptId,
    Map<String, dynamic> payload,
  ) async => PurchaseReceipt.fromJson(
    Map<String, dynamic>.from(
      await _api.patch(
            'finance/purchase-receipts/$receiptId',
            data: payload,
          )
          as Map,
    ),
  );

  Future<PurchaseReceipt> postReceipt(
    int receiptId,
    String idempotencyKey,
  ) async => PurchaseReceipt.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            'finance/purchase-receipts/$receiptId/post',
            data: <String, dynamic>{'idempotencyKey': idempotencyKey},
          )
          as Map,
    ),
  );
}
