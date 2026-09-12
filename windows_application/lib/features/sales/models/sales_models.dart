import '../../pos/models/json_helpers.dart';

class SalesCustomer {
  const SalesCustomer({required this.id, required this.name, required this.customerNumber, required this.creditTermsDays, required this.isActive, required this.isWalkIn});
  final int id; final String name; final String customerNumber; final int creditTermsDays; final bool isActive; final bool isWalkIn;
  factory SalesCustomer.fromJson(Map<String, dynamic> j) => SalesCustomer(id: readInt(j['id']) ?? 0, name: readString(j['name']), customerNumber: readString(j['customerNumber']), creditTermsDays: readInt(j['defaultCreditTermsDays']) ?? 0, isActive: readBool(j['isActive']), isWalkIn: readBool(j['isWalkIn']));
}

class SalesVariant { const SalesVariant({required this.id, required this.name, required this.isDefault}); final int id; final String name; final bool isDefault; factory SalesVariant.fromJson(Map<String, dynamic> j) => SalesVariant(id: readInt(j['id']) ?? 0, name: readString(j['name']), isDefault: readBool(j['isDefault'])); }
class SalesProduct {
  const SalesProduct({required this.id, required this.name, required this.salePrice, this.sku, this.categoryName, this.variants = const <SalesVariant>[]});
  final int id; final String name; final String salePrice; final String? sku; final String? categoryName; final List<SalesVariant> variants;
  factory SalesProduct.fromJson(Map<String, dynamic> j) => SalesProduct(id: readInt(j['id']) ?? 0, name: readString(j['name']), salePrice: readString(j['salePrice']), sku: readString(j['sku']).isEmpty ? null : readString(j['sku']), categoryName: readString(j['categoryName']).isEmpty ? null : readString(j['categoryName']), variants: readMapList(j['variants']).map(SalesVariant.fromJson).toList(growable: false));
}

class SalesInvoiceLine {
  const SalesInvoiceLine({required this.productId, required this.productName, required this.quantity, required this.unitPrice, required this.taxTotal, required this.total, this.variantId, this.cogsTotal});
  final int productId; final String productName; final String quantity; final String unitPrice; final String taxTotal; final String total; final int? variantId; final String? cogsTotal;
  factory SalesInvoiceLine.fromJson(Map<String, dynamic> j) => SalesInvoiceLine(productId: readInt(j['productId']) ?? 0, productName: readString(j['productName']), quantity: readString(j['quantity']), unitPrice: readString(j['unitPrice']), taxTotal: readString(j['taxTotal']), total: readString(j['total']), variantId: readInt(j['variantId']), cogsTotal: readString(j['cogsTotal']).isEmpty ? null : readString(j['cogsTotal']));
}

class SalesPostingPreview { const SalesPostingPreview({required this.ar, required this.revenue, required this.tax, required this.cogs, required this.inventoryAsset, required this.materials}); final String ar; final String revenue; final String tax; final String cogs; final String inventoryAsset; final List<SalesPreviewMaterial> materials; factory SalesPostingPreview.fromJson(Map<String, dynamic> j) { final a = j['accounting'] is Map ? Map<String, dynamic>.from(j['accounting'] as Map) : const <String, dynamic>{}; final c = j['cogs'] is Map ? Map<String, dynamic>.from(j['cogs'] as Map) : const <String, dynamic>{}; return SalesPostingPreview(ar: readString(a['accountsReceivableDebit']), revenue: readString(a['revenueCredit']), tax: readString(a['taxCredit']), cogs: readString(c['cogsDebit']), inventoryAsset: readString(c['inventoryCredit']), materials: readMapList(j['inventory']).map(SalesPreviewMaterial.fromJson).toList(growable: false)); } }
class SalesPreviewMaterial { const SalesPreviewMaterial({required this.name, required this.quantity, required this.unit, required this.warehouse}); final String name; final String quantity; final String unit; final String warehouse; factory SalesPreviewMaterial.fromJson(Map<String, dynamic> j) => SalesPreviewMaterial(name: readString(j['materialName']), quantity: readString(j['quantityToConsume']), unit: readString(j['baseUnit']), warehouse: readString(j['warehouseName'])); }

class CustomerPaymentCollection {
  const CustomerPaymentCollection({required this.paymentId, required this.paymentNumber, required this.paymentDate, required this.paymentMethodName, required this.amount});
  final int paymentId; final String paymentNumber; final String paymentDate; final String paymentMethodName; final String amount;
  factory CustomerPaymentCollection.fromJson(Map<String, dynamic> j) => CustomerPaymentCollection(paymentId: readInt(j['paymentId']) ?? 0, paymentNumber: readString(j['paymentNumber']), paymentDate: readString(j['paymentDate']), paymentMethodName: readString(j['paymentMethodName']), amount: readString(j['amount'], fallback: '0.00'));
}

/// One posted Credit Note as it appears in an invoice's history (§36).
class InvoiceCreditNoteEntry {
  const InvoiceCreditNoteEntry({required this.id, required this.creditNoteNumber, required this.creditDate, required this.total, required this.arReductionAmount, required this.customerCreditAmount, this.reason});
  final int id; final String creditNoteNumber; final String creditDate; final String total; final String arReductionAmount; final String customerCreditAmount; final String? reason;
  factory InvoiceCreditNoteEntry.fromJson(Map<String, dynamic> j) => InvoiceCreditNoteEntry(id: readInt(j['id']) ?? 0, creditNoteNumber: readString(j['creditNoteNumber']), creditDate: readString(j['creditDate']), total: readString(j['total'], fallback: '0.00'), arReductionAmount: readString(j['arReductionAmount'], fallback: '0.00'), customerCreditAmount: readString(j['customerCreditAmount'], fallback: '0.00'), reason: readString(j['reason']).isEmpty ? null : readString(j['reason']));
}

class SalesInvoice {
  const SalesInvoice({required this.id, required this.invoiceNumber, required this.customerId, required this.customerName, required this.branchId, required this.branchName, required this.invoiceDate, required this.dueDate, required this.status, required this.subtotal, required this.taxTotal, required this.total, required this.allowedActions, this.reference, this.notes, this.createdBy, this.accountingStatus, this.paymentStatus, this.journalReference, this.receivableAmount, this.paidAmount, this.remainingAmount, this.isOverdue = false, this.creditedAmount, this.creditStatus, this.lines = const <SalesInvoiceLine>[], this.collections = const <CustomerPaymentCollection>[], this.creditNotes = const <InvoiceCreditNoteEntry>[]});
  final int id; final String invoiceNumber; final int customerId; final String customerName; final int branchId; final String branchName; final String invoiceDate; final String? dueDate; final String status; final String subtotal; final String taxTotal; final String total; final Map<String, bool> allowedActions; final String? reference; final String? notes; final String? createdBy; final String? accountingStatus; final String? paymentStatus; final String? journalReference; final String? receivableAmount; final String? paidAmount; final String? remainingAmount; final bool isOverdue; final String? creditedAmount; final String? creditStatus; final List<SalesInvoiceLine> lines; final List<CustomerPaymentCollection> collections; final List<InvoiceCreditNoteEntry> creditNotes;
  bool get canEdit => allowedActions['canEdit'] ?? false; bool get canCancel => allowedActions['canCancel'] ?? false; bool get canPost => allowedActions['canPost'] ?? false; bool get canRegisterPayment => allowedActions['canRegisterPayment'] ?? false; bool get canCreateCreditNote => allowedActions['canCreateCreditNote'] ?? false;
  factory SalesInvoice.fromJson(Map<String, dynamic> j) => SalesInvoice(id: readInt(j['id']) ?? 0, invoiceNumber: readString(j['invoiceNumber']), customerId: readInt(j['customerId']) ?? 0, customerName: readString(j['customerName']), branchId: readInt(j['branchId']) ?? 0, branchName: readString(j['branchName']), invoiceDate: readString(j['invoiceDate']), dueDate: readString(j['dueDate']).isEmpty ? null : readString(j['dueDate']), status: readString(j['status']), subtotal: readString(j['subtotal']), taxTotal: readString(j['taxTotal']), total: readString(j['total']), allowedActions: (j['allowedActions'] is Map ? Map<String, dynamic>.from(j['allowedActions'] as Map) : const <String, dynamic>{}).map((k, v) => MapEntry(k, v == true)), reference: readString(j['reference']).isEmpty ? null : readString(j['reference']), notes: readString(j['notes']).isEmpty ? null : readString(j['notes']), createdBy: readString(j['createdBy']).isEmpty ? null : readString(j['createdBy']), accountingStatus: readString(j['accountingStatus']).isEmpty ? null : readString(j['accountingStatus']), paymentStatus: readString(j['paymentStatus']).isEmpty ? null : readString(j['paymentStatus']), journalReference: readString(j['journalReference']).isEmpty ? null : readString(j['journalReference']), receivableAmount: readString(j['receivableAmount']).isEmpty ? null : readString(j['receivableAmount']), paidAmount: readString(j['paidAmount']).isEmpty ? null : readString(j['paidAmount']), remainingAmount: readString(j['remainingAmount']).isEmpty ? null : readString(j['remainingAmount']), isOverdue: readBool(j['isOverdue']), creditedAmount: readString(j['creditedAmount']).isEmpty ? null : readString(j['creditedAmount']), creditStatus: readString(j['creditStatus']).isEmpty ? null : readString(j['creditStatus']), lines: readMapList(j['lines']).map(SalesInvoiceLine.fromJson).toList(growable: false), collections: readMapList(j['collections']).map(CustomerPaymentCollection.fromJson).toList(growable: false), creditNotes: readMapList(j['creditNotes']).map(InvoiceCreditNoteEntry.fromJson).toList(growable: false));
}

class SalesInvoicePage {
  const SalesInvoicePage({required this.items, required this.currentPage, required this.lastPage, required this.total, required this.draftCount, required this.draftTotal});
  final List<SalesInvoice> items; final int currentPage; final int lastPage; final int total; final int draftCount; final String draftTotal;
}

/// One open (remaining > 0) posted invoice, as returned by the customer
/// receivables endpoint — already ordered oldest-due-first by the server,
/// the same order "توزيع تلقائي" fills against (§10).
class OpenReceivableInvoice {
  const OpenReceivableInvoice({required this.id, required this.invoiceNumber, required this.invoiceDate, required this.dueDate, required this.total, required this.paid, required this.remaining, required this.isOverdue});
  final int id; final String invoiceNumber; final String invoiceDate; final String? dueDate; final String total; final String paid; final String remaining; final bool isOverdue;
  factory OpenReceivableInvoice.fromJson(Map<String, dynamic> j) => OpenReceivableInvoice(id: readInt(j['id']) ?? 0, invoiceNumber: readString(j['invoiceNumber']), invoiceDate: readString(j['invoiceDate']), dueDate: readString(j['dueDate']).isEmpty ? null : readString(j['dueDate']), total: readString(j['total'], fallback: '0.00'), paid: readString(j['paid'], fallback: '0.00'), remaining: readString(j['remaining'], fallback: '0.00'), isOverdue: readBool(j['isOverdue']));
}

class CustomerReceivablesSummary {
  const CustomerReceivablesSummary({required this.customerId, required this.customerName, required this.outstanding, required this.openInvoices});
  final int customerId; final String customerName; final String outstanding; final List<OpenReceivableInvoice> openInvoices;
  factory CustomerReceivablesSummary.fromJson(Map<String, dynamic> j) { final c = j['customer'] is Map ? Map<String, dynamic>.from(j['customer'] as Map) : const <String, dynamic>{}; return CustomerReceivablesSummary(customerId: readInt(c['id']) ?? 0, customerName: readString(c['name']), outstanding: readString(j['outstanding'], fallback: '0.00'), openInvoices: readMapList(j['openInvoices']).map(OpenReceivableInvoice.fromJson).toList(growable: false)); }
}

/// §33 minimal customer/AR overview row — no aging suite.
class CustomerReceivableOverviewRow {
  const CustomerReceivableOverviewRow({required this.customerId, required this.customerName, required this.customerNumber, required this.invoiceCount, required this.totalInvoiced, required this.totalPaid, required this.outstanding});
  final int customerId; final String customerName; final String customerNumber; final int invoiceCount; final String totalInvoiced; final String totalPaid; final String outstanding;
  factory CustomerReceivableOverviewRow.fromJson(Map<String, dynamic> j) => CustomerReceivableOverviewRow(customerId: readInt(j['customerId']) ?? 0, customerName: readString(j['customerName']), customerNumber: readString(j['customerNumber']), invoiceCount: readInt(j['invoiceCount']) ?? 0, totalInvoiced: readString(j['totalInvoiced'], fallback: '0.00'), totalPaid: readString(j['totalPaid'], fallback: '0.00'), outstanding: readString(j['outstanding'], fallback: '0.00'));
}

class CustomerPaymentAllocation {
  const CustomerPaymentAllocation({required this.invoiceId, required this.invoiceNumber, required this.amount});
  final int invoiceId; final String invoiceNumber; final String amount;
  factory CustomerPaymentAllocation.fromJson(Map<String, dynamic> j) => CustomerPaymentAllocation(invoiceId: readInt(j['invoiceId']) ?? 0, invoiceNumber: readString(j['invoiceNumber']), amount: readString(j['amount'], fallback: '0.00'));
}

class CustomerPayment {
  const CustomerPayment({required this.id, required this.paymentNumber, required this.customerId, required this.customerName, required this.branchId, required this.branchName, required this.paymentDate, required this.amount, required this.paymentMethodName, required this.financialLocationName, required this.status, this.reference, this.notes, this.journalEntryId, this.reversalJournalEntryId, this.createdAt, this.allocations = const <CustomerPaymentAllocation>[], this.allowedActions = const <String>[]});
  final int id; final String paymentNumber; final int customerId; final String customerName; final int branchId; final String branchName; final String paymentDate; final String amount; final String paymentMethodName; final String financialLocationName; final String status; final String? reference; final String? notes; final int? journalEntryId; final int? reversalJournalEntryId; final String? createdAt; final List<CustomerPaymentAllocation> allocations; final List<String> allowedActions;
  bool get canReverse => allowedActions.contains('reverse');
  factory CustomerPayment.fromJson(Map<String, dynamic> j) => CustomerPayment(id: readInt(j['id']) ?? 0, paymentNumber: readString(j['paymentNumber']), customerId: readInt(j['customerId']) ?? 0, customerName: readString(j['customerName']), branchId: readInt(j['branchId']) ?? 0, branchName: readString(j['branchName']), paymentDate: readString(j['paymentDate']), amount: readString(j['amount'], fallback: '0.00'), paymentMethodName: readString(j['paymentMethodName']), financialLocationName: readString(j['financialLocationName']), status: readString(j['status']), reference: readString(j['reference']).isEmpty ? null : readString(j['reference']), notes: readString(j['notes']).isEmpty ? null : readString(j['notes']), journalEntryId: readInt(j['journalEntryId']), reversalJournalEntryId: readInt(j['reversalJournalEntryId']), createdAt: readString(j['createdAt']).isEmpty ? null : readString(j['createdAt']), allocations: readMapList(j['allocations']).map(CustomerPaymentAllocation.fromJson).toList(growable: false), allowedActions: readStringList(j['allowedActions']));
}

class CustomerPaymentPreviewAllocation {
  const CustomerPaymentPreviewAllocation({required this.invoiceId, required this.invoiceNumber, required this.total, required this.remainingBefore, required this.allocated, required this.remainingAfter, required this.paymentStatusAfter});
  final int invoiceId; final String invoiceNumber; final String total; final String remainingBefore; final String allocated; final String remainingAfter; final String paymentStatusAfter;
  factory CustomerPaymentPreviewAllocation.fromJson(Map<String, dynamic> j) => CustomerPaymentPreviewAllocation(invoiceId: readInt(j['invoiceId']) ?? 0, invoiceNumber: readString(j['invoiceNumber']), total: readString(j['total'], fallback: '0.00'), remainingBefore: readString(j['remainingBefore'], fallback: '0.00'), allocated: readString(j['allocated'], fallback: '0.00'), remainingAfter: readString(j['remainingAfter'], fallback: '0.00'), paymentStatusAfter: readString(j['paymentStatusAfter']));
}

class CustomerPaymentPreview {
  const CustomerPaymentPreview({required this.customerName, required this.amount, required this.debitAccountCode, required this.creditAccountCode, required this.allocations});
  final String customerName; final String amount; final String debitAccountCode; final String creditAccountCode; final List<CustomerPaymentPreviewAllocation> allocations;
  factory CustomerPaymentPreview.fromJson(Map<String, dynamic> j) { final c = j['customer'] is Map ? Map<String, dynamic>.from(j['customer'] as Map) : const <String, dynamic>{}; final a = j['accounting'] is Map ? Map<String, dynamic>.from(j['accounting'] as Map) : const <String, dynamic>{}; return CustomerPaymentPreview(customerName: readString(c['name']), amount: readString(j['amount'], fallback: '0.00'), debitAccountCode: readString(a['debitAccountCode']), creditAccountCode: readString(a['creditAccountCode']), allocations: readMapList(j['allocations']).map(CustomerPaymentPreviewAllocation.fromJson).toList(growable: false)); }
}

// ---- Phase 4: Sales Credit Notes / Returns / Customer Refunds ------------

/// One original invoice line annotated with already-returned/returnable
/// quantities — feeds the "Create Credit Note" wizard (§33).
class ReturnableInvoiceLine {
  const ReturnableInvoiceLine({required this.originalSalesInvoiceLineId, required this.productId, required this.productName, required this.productSku, required this.originalQuantity, required this.alreadyReturned, required this.returnable, required this.unitPrice, required this.taxRate, required this.isStockTracked});
  final int originalSalesInvoiceLineId; final int productId; final String productName; final String? productSku; final String originalQuantity; final String alreadyReturned; final String returnable; final String unitPrice; final String taxRate; final bool isStockTracked;
  factory ReturnableInvoiceLine.fromJson(Map<String, dynamic> j) => ReturnableInvoiceLine(originalSalesInvoiceLineId: readInt(j['originalSalesInvoiceLineId']) ?? 0, productId: readInt(j['productId']) ?? 0, productName: readString(j['productName']), productSku: readString(j['productSku']).isEmpty ? null : readString(j['productSku']), originalQuantity: readString(j['originalQuantity'], fallback: '0.000'), alreadyReturned: readString(j['alreadyReturned'], fallback: '0.000'), returnable: readString(j['returnable'], fallback: '0.000'), unitPrice: readString(j['unitPrice'], fallback: '0.00'), taxRate: readString(j['taxRate'], fallback: '0'), isStockTracked: readBool(j['isStockTracked']));
}

class SalesCreditNoteLine {
  const SalesCreditNoteLine({required this.id, required this.originalSalesInvoiceLineId, required this.productId, required this.productName, required this.quantity, required this.unitPrice, required this.subtotal, required this.taxTotal, required this.total, required this.restock, this.productSku, this.cogsTotal});
  final int id; final int originalSalesInvoiceLineId; final int productId; final String productName; final String? productSku; final String quantity; final String unitPrice; final String subtotal; final String taxTotal; final String total; final bool restock; final String? cogsTotal;
  factory SalesCreditNoteLine.fromJson(Map<String, dynamic> j) => SalesCreditNoteLine(id: readInt(j['id']) ?? 0, originalSalesInvoiceLineId: readInt(j['originalSalesInvoiceLineId']) ?? 0, productId: readInt(j['productId']) ?? 0, productName: readString(j['productName']), productSku: readString(j['productSku']).isEmpty ? null : readString(j['productSku']), quantity: readString(j['quantity'], fallback: '0.000'), unitPrice: readString(j['unitPrice'], fallback: '0.00'), subtotal: readString(j['subtotal'], fallback: '0.00'), taxTotal: readString(j['taxTotal'], fallback: '0.00'), total: readString(j['total'], fallback: '0.00'), restock: readBool(j['restock']), cogsTotal: readString(j['cogsTotal']).isEmpty ? null : readString(j['cogsTotal']));
}

class SalesCreditNote {
  const SalesCreditNote({required this.id, required this.creditNoteNumber, required this.branchId, required this.branchName, required this.customerId, required this.customerName, required this.originalSalesInvoiceId, required this.originalInvoiceNumber, required this.creditDate, required this.status, required this.subtotal, required this.taxTotal, required this.total, required this.allowedActions, this.reason, this.arReductionAmount, this.customerCreditAmount, this.createdBy, this.postedAt, this.lines = const <SalesCreditNoteLine>[]});
  final int id; final String creditNoteNumber; final int branchId; final String branchName; final int customerId; final String customerName; final int originalSalesInvoiceId; final String originalInvoiceNumber; final String creditDate; final String? reason; final String status; final String subtotal; final String taxTotal; final String total; final String? arReductionAmount; final String? customerCreditAmount; final Map<String, bool> allowedActions; final String? createdBy; final String? postedAt; final List<SalesCreditNoteLine> lines;
  bool get canCancel => allowedActions['canCancel'] ?? false; bool get canPost => allowedActions['canPost'] ?? false;
  factory SalesCreditNote.fromJson(Map<String, dynamic> j) => SalesCreditNote(id: readInt(j['id']) ?? 0, creditNoteNumber: readString(j['creditNoteNumber']), branchId: readInt(j['branchId']) ?? 0, branchName: readString(j['branchName']), customerId: readInt(j['customerId']) ?? 0, customerName: readString(j['customerName']), originalSalesInvoiceId: readInt(j['originalSalesInvoiceId']) ?? 0, originalInvoiceNumber: readString(j['originalInvoiceNumber']), creditDate: readString(j['creditDate']), reason: readString(j['reason']).isEmpty ? null : readString(j['reason']), status: readString(j['status']), subtotal: readString(j['subtotal'], fallback: '0.00'), taxTotal: readString(j['taxTotal'], fallback: '0.00'), total: readString(j['total'], fallback: '0.00'), arReductionAmount: readString(j['arReductionAmount']).isEmpty ? null : readString(j['arReductionAmount']), customerCreditAmount: readString(j['customerCreditAmount']).isEmpty ? null : readString(j['customerCreditAmount']), allowedActions: (j['allowedActions'] is Map ? Map<String, dynamic>.from(j['allowedActions'] as Map) : const <String, dynamic>{}).map((k, v) => MapEntry(k, v == true)), createdBy: readString(j['createdBy']).isEmpty ? null : readString(j['createdBy']), postedAt: readString(j['postedAt']).isEmpty ? null : readString(j['postedAt']), lines: readMapList(j['lines']).map(SalesCreditNoteLine.fromJson).toList(growable: false));
}

class SalesCreditNotePreviewLine {
  const SalesCreditNotePreviewLine({required this.lineId, required this.productName, required this.quantity, required this.subtotal, required this.tax, required this.total, required this.restock, required this.cogsReversal});
  final int lineId; final String productName; final String quantity; final String subtotal; final String tax; final String total; final bool restock; final String cogsReversal;
  factory SalesCreditNotePreviewLine.fromJson(Map<String, dynamic> j) => SalesCreditNotePreviewLine(lineId: readInt(j['lineId']) ?? 0, productName: readString(j['productName']), quantity: readString(j['quantity'], fallback: '0.000'), subtotal: readString(j['subtotal'], fallback: '0.00'), tax: readString(j['tax'], fallback: '0.00'), total: readString(j['total'], fallback: '0.00'), restock: readBool(j['restock']), cogsReversal: readString(j['cogsReversal'], fallback: '0.00'));
}

class SalesCreditNotePreview {
  const SalesCreditNotePreview({required this.subtotal, required this.tax, required this.total, required this.arReduction, required this.customerCreditCreated, required this.outstandingBefore, required this.lines});
  final String subtotal; final String tax; final String total; final String arReduction; final String customerCreditCreated; final String outstandingBefore; final List<SalesCreditNotePreviewLine> lines;
  factory SalesCreditNotePreview.fromJson(Map<String, dynamic> j) {
    final note = j['creditNote'] is Map ? Map<String, dynamic>.from(j['creditNote'] as Map) : const <String, dynamic>{};
    final impact = j['invoiceImpact'] is Map ? Map<String, dynamic>.from(j['invoiceImpact'] as Map) : const <String, dynamic>{};
    return SalesCreditNotePreview(subtotal: readString(note['subtotal'], fallback: '0.00'), tax: readString(note['tax'], fallback: '0.00'), total: readString(note['total'], fallback: '0.00'), arReduction: readString(impact['arReduction'], fallback: '0.00'), customerCreditCreated: readString(impact['customerCreditCreated'], fallback: '0.00'), outstandingBefore: readString(impact['outstandingBefore'], fallback: '0.00'), lines: readMapList(j['lines']).map(SalesCreditNotePreviewLine.fromJson).toList(growable: false));
  }
}

class CustomerCreditInfo {
  const CustomerCreditInfo({required this.customerId, required this.customerName, required this.availableCredit});
  final int customerId; final String customerName; final String availableCredit;
  factory CustomerCreditInfo.fromJson(Map<String, dynamic> j) { final c = j['customer'] is Map ? Map<String, dynamic>.from(j['customer'] as Map) : const <String, dynamic>{}; return CustomerCreditInfo(customerId: readInt(c['id']) ?? 0, customerName: readString(c['name']), availableCredit: readString(j['availableCredit'], fallback: '0.00')); }
}

class CustomerRefundPreview {
  const CustomerRefundPreview({required this.customerName, required this.availableCredit, required this.amount, required this.availableCreditAfter, required this.debitAccountCode, required this.creditAccountCode});
  final String customerName; final String availableCredit; final String amount; final String availableCreditAfter; final String debitAccountCode; final String creditAccountCode;
  factory CustomerRefundPreview.fromJson(Map<String, dynamic> j) { final c = j['customer'] is Map ? Map<String, dynamic>.from(j['customer'] as Map) : const <String, dynamic>{}; final a = j['accounting'] is Map ? Map<String, dynamic>.from(j['accounting'] as Map) : const <String, dynamic>{}; return CustomerRefundPreview(customerName: readString(c['name']), availableCredit: readString(j['availableCredit'], fallback: '0.00'), amount: readString(j['amount'], fallback: '0.00'), availableCreditAfter: readString(j['availableCreditAfter'], fallback: '0.00'), debitAccountCode: readString(a['debitAccountCode']), creditAccountCode: readString(a['creditAccountCode'])); }
}

class CustomerRefund {
  const CustomerRefund({required this.id, required this.refundNumber, required this.customerId, required this.customerName, required this.branchId, required this.branchName, required this.refundDate, required this.amount, required this.paymentMethodName, required this.financialLocationName, required this.status, this.reference, this.notes, this.journalEntryId, this.createdAt});
  final int id; final String refundNumber; final int customerId; final String customerName; final int branchId; final String branchName; final String refundDate; final String amount; final String paymentMethodName; final String financialLocationName; final String status; final String? reference; final String? notes; final int? journalEntryId; final String? createdAt;
  factory CustomerRefund.fromJson(Map<String, dynamic> j) => CustomerRefund(id: readInt(j['id']) ?? 0, refundNumber: readString(j['refundNumber']), customerId: readInt(j['customerId']) ?? 0, customerName: readString(j['customerName']), branchId: readInt(j['branchId']) ?? 0, branchName: readString(j['branchName']), refundDate: readString(j['refundDate']), amount: readString(j['amount'], fallback: '0.00'), paymentMethodName: readString(j['paymentMethodName']), financialLocationName: readString(j['financialLocationName']), status: readString(j['status']), reference: readString(j['reference']).isEmpty ? null : readString(j['reference']), notes: readString(j['notes']).isEmpty ? null : readString(j['notes']), journalEntryId: readInt(j['journalEntryId']), createdAt: readString(j['createdAt']).isEmpty ? null : readString(j['createdAt']));
}
