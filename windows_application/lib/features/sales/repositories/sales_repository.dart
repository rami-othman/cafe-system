import '../../../core/network/dio_api_client.dart';
import '../../pos/models/json_helpers.dart';
import '../models/sales_models.dart';

class SalesRepository {
  const SalesRepository(this._api); final DioApiClient _api;
  Future<SalesInvoicePage> invoices({Map<String, dynamic>? query}) async { final Map<String, dynamic> r = Map<String, dynamic>.from(await _api.getEnvelope('finance/sales-invoices', queryParameters: query) as Map); final Map<String, dynamic> m = r['meta'] is Map ? Map<String, dynamic>.from(r['meta'] as Map) : const <String, dynamic>{}; final Map<String, dynamic> s = r['summary'] is Map ? Map<String, dynamic>.from(r['summary'] as Map) : const <String, dynamic>{}; return SalesInvoicePage(items: readMapList(r['data']).map(SalesInvoice.fromJson).toList(growable: false), currentPage: readInt(m['currentPage']) ?? 1, lastPage: readInt(m['lastPage']) ?? 1, total: readInt(m['total']) ?? 0, draftCount: readInt(s['draftInvoiceCount']) ?? 0, draftTotal: readString(s['draftInvoiceTotal'], fallback: '0.00')); }
  Future<SalesInvoice> invoice(int id) async => SalesInvoice.fromJson(Map<String, dynamic>.from(await _api.get('finance/sales-invoices/$id') as Map));
  Future<SalesInvoice> save(Map<String, dynamic> data, {int? id}) async => SalesInvoice.fromJson(Map<String, dynamic>.from((id == null ? await _api.post('finance/sales-invoices', data: data) : await _api.patch('finance/sales-invoices/$id', data: data)) as Map));
  Future<SalesInvoice> cancel(int id, {String? reason}) async => SalesInvoice.fromJson(Map<String, dynamic>.from(await _api.post('finance/sales-invoices/$id/cancel', data: <String, dynamic>{if (reason != null) 'reason': reason}) as Map));
  Future<SalesInvoice> post(int id, String idempotencyKey) async => SalesInvoice.fromJson(Map<String, dynamic>.from(await _api.post('finance/sales-invoices/$id/post', data: <String, dynamic>{'idempotencyKey': idempotencyKey}) as Map));
  Future<SalesPostingPreview> postingPreview(int id) async => SalesPostingPreview.fromJson(Map<String, dynamic>.from(await _api.get('finance/sales-invoices/$id/posting-preview') as Map));
  Future<List<SalesCustomer>> customers({String? search}) async { final Map<String, dynamic> r = Map<String, dynamic>.from(await _api.getEnvelope('finance/customers', queryParameters: <String, dynamic>{'status': 'active', if (search != null && search.isNotEmpty) 'search': search, 'perPage': 100}) as Map); return readMapList(r['data']).map(SalesCustomer.fromJson).toList(growable: false); }
  Future<SalesCustomer> createCustomer(Map<String, dynamic> data) async => SalesCustomer.fromJson(Map<String, dynamic>.from(await _api.post('finance/customers', data: data) as Map));
  Future<List<SalesProduct>> products({String? search}) async { final Map<String, dynamic> r = Map<String, dynamic>.from(await _api.getEnvelope('finance/sales-products', queryParameters: <String, dynamic>{if (search != null && search.isNotEmpty) 'search': search, 'perPage': 100}) as Map); return readMapList(r['data']).map(SalesProduct.fromJson).toList(growable: false); }

  // ---- Customer Payments / AR (Phase 3) ---------------------------------

  Future<CustomerReceivablesSummary> customerReceivables(int customerId) async => CustomerReceivablesSummary.fromJson(Map<String, dynamic>.from(await _api.get('finance/customers/$customerId/receivables') as Map));
  Future<List<CustomerReceivableOverviewRow>> receivablesOverview() async => readMapList(await _api.get('finance/customers-receivables')).map(CustomerReceivableOverviewRow.fromJson).toList(growable: false);
  Future<CustomerPaymentPreview> previewPayment(Map<String, dynamic> data) async => CustomerPaymentPreview.fromJson(Map<String, dynamic>.from(await _api.post('finance/customer-payments/preview', data: data) as Map));
  Future<CustomerPayment> registerPayment(Map<String, dynamic> data) async => CustomerPayment.fromJson(Map<String, dynamic>.from(await _api.post('finance/customer-payments', data: data) as Map));
  Future<CustomerPayment> payment(int id) async => CustomerPayment.fromJson(Map<String, dynamic>.from(await _api.get('finance/customer-payments/$id') as Map));
  Future<CustomerPayment> reversePayment(int id, {String? reason}) async => CustomerPayment.fromJson(Map<String, dynamic>.from(await _api.post('finance/customer-payments/$id/reverse', data: <String, dynamic>{if (reason != null && reason.isNotEmpty) 'reason': reason}) as Map));
  Future<Map<String, dynamic>> postAndCollect(int invoiceId, Map<String, dynamic> data) async => Map<String, dynamic>.from(await _api.post('finance/sales-invoices/$invoiceId/post-and-collect', data: data) as Map);

  // ---- Sales Credit Notes / Returns / Customer Refunds (Phase 4) --------

  Future<List<ReturnableInvoiceLine>> returnableLines(int invoiceId) async => readMapList(await _api.get('finance/sales-invoices/$invoiceId/returnable-lines')).map(ReturnableInvoiceLine.fromJson).toList(growable: false);
  Future<List<SalesCreditNote>> creditNotes({Map<String, dynamic>? query}) async { final Map<String, dynamic> r = Map<String, dynamic>.from(await _api.getEnvelope('finance/sales-credit-notes', queryParameters: query) as Map); return readMapList(r['data']).map(SalesCreditNote.fromJson).toList(growable: false); }
  Future<SalesCreditNote> saveCreditNote(Map<String, dynamic> data) async => SalesCreditNote.fromJson(Map<String, dynamic>.from(await _api.post('finance/sales-credit-notes', data: data) as Map));
  Future<SalesCreditNote> creditNote(int id) async => SalesCreditNote.fromJson(Map<String, dynamic>.from(await _api.get('finance/sales-credit-notes/$id') as Map));
  Future<SalesCreditNote> cancelCreditNote(int id) async => SalesCreditNote.fromJson(Map<String, dynamic>.from(await _api.post('finance/sales-credit-notes/$id/cancel', data: const <String, dynamic>{}) as Map));
  Future<SalesCreditNotePreview> creditNotePostingPreview(int id) async => SalesCreditNotePreview.fromJson(Map<String, dynamic>.from(await _api.get('finance/sales-credit-notes/$id/posting-preview') as Map));
  Future<SalesCreditNote> postCreditNote(int id, String idempotencyKey) async => SalesCreditNote.fromJson(Map<String, dynamic>.from(await _api.post('finance/sales-credit-notes/$id/post', data: <String, dynamic>{'idempotencyKey': idempotencyKey}) as Map));

  Future<CustomerCreditInfo> customerCredit(int customerId) async => CustomerCreditInfo.fromJson(Map<String, dynamic>.from(await _api.get('finance/customers/$customerId/credit') as Map));
  Future<CustomerRefundPreview> previewRefund(Map<String, dynamic> data) async => CustomerRefundPreview.fromJson(Map<String, dynamic>.from(await _api.post('finance/customer-refunds/preview', data: data) as Map));
  Future<CustomerRefund> registerRefund(Map<String, dynamic> data) async => CustomerRefund.fromJson(Map<String, dynamic>.from(await _api.post('finance/customer-refunds', data: data) as Map));
  Future<CustomerRefund> refund(int id) async => CustomerRefund.fromJson(Map<String, dynamic>.from(await _api.get('finance/customer-refunds/$id') as Map));
}
