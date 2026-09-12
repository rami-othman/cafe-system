import '../../pos/models/json_helpers.dart';

/// Purchasing Phase 1+2 line item. Subordinate to a supplier invoice — never
/// a standalone record. `receivedQuantity`/`remainingQuantity` are cached
/// rollups maintained transactionally by the backend's
/// PurchaseReceivingService every time a Goods Receipt posts — never edited
/// from Flutter directly. `remainingQuantity` is null for non-inventory
/// lines (nothing to receive against a service/asset line).
class PurchaseInvoiceLine {
  const PurchaseInvoiceLine({
    required this.id,
    required this.lineNumber,
    required this.lineType,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.taxAmount,
    required this.lineTotal,
    required this.receivedQuantity,
    this.inventoryItemId,
    this.inventoryItemName,
    this.purchaseUnit,
    this.baseUnit,
    this.conversionFactor,
    this.baseQuantity,
    this.warehouseId,
    this.remainingQuantity,
  });

  final int id;
  final int lineNumber;
  final String lineType;
  final String description;
  final int? inventoryItemId;
  final String? inventoryItemName;
  final String? purchaseUnit;
  final String? baseUnit;
  final String quantity;
  final String? conversionFactor;
  final String? baseQuantity;
  final String unitPrice;
  final String discountAmount;
  final String taxAmount;
  final String lineTotal;
  final int? warehouseId;
  final String receivedQuantity;
  final String? remainingQuantity;

  bool get isInventory => lineType == 'inventory';
  bool get hasRemainingToReceive =>
      isInventory && (double.tryParse(remainingQuantity ?? '0') ?? 0) > 0;

  factory PurchaseInvoiceLine.fromJson(Map<String, dynamic> json) =>
      PurchaseInvoiceLine(
        id: readInt(json['id']) ?? 0,
        lineNumber: readInt(json['lineNumber']) ?? 0,
        lineType: readString(json['lineType']),
        description: readString(json['description']),
        inventoryItemId: readInt(json['inventoryItemId']),
        inventoryItemName: readString(json['inventoryItemName']).isEmpty
            ? null
            : readString(json['inventoryItemName']),
        purchaseUnit: readString(json['purchaseUnit']).isEmpty
            ? null
            : readString(json['purchaseUnit']),
        baseUnit: readString(json['baseUnit']).isEmpty
            ? null
            : readString(json['baseUnit']),
        quantity: readString(json['quantity']),
        conversionFactor: readString(json['conversionFactor']).isEmpty
            ? null
            : readString(json['conversionFactor']),
        baseQuantity: readString(json['baseQuantity']).isEmpty
            ? null
            : readString(json['baseQuantity']),
        unitPrice: readString(json['unitPrice']),
        discountAmount: readString(json['discountAmount'], fallback: '0.00'),
        taxAmount: readString(json['taxAmount'], fallback: '0.00'),
        lineTotal: readString(json['lineTotal']),
        warehouseId: readInt(json['warehouseId']),
        receivedQuantity: readString(
          json['receivedQuantity'],
          fallback: '0.000',
        ),
        remainingQuantity: json['remainingQuantity'] == null
            ? null
            : readString(json['remainingQuantity']),
      );
}

/// A single Goods Receipt line — see PurchaseReceipt.
class PurchaseReceiptLine {
  const PurchaseReceiptLine({
    required this.id,
    required this.supplierInvoiceLineId,
    required this.inventoryItemId,
    required this.itemName,
    required this.warehouseId,
    required this.warehouseName,
    required this.receivedUnit,
    required this.baseUnit,
    required this.receivedQuantity,
    required this.baseQuantity,
    required this.unitCost,
    this.stockMovementId,
  });

  final int id;
  final int supplierInvoiceLineId;
  final int inventoryItemId;
  final String itemName;
  final int warehouseId;
  final String warehouseName;
  final String receivedUnit;
  final String baseUnit;
  final String receivedQuantity;
  final String baseQuantity;
  final String unitCost;
  final int? stockMovementId;

  factory PurchaseReceiptLine.fromJson(Map<String, dynamic> json) =>
      PurchaseReceiptLine(
        id: readInt(json['id']) ?? 0,
        supplierInvoiceLineId: readInt(json['supplierInvoiceLineId']) ?? 0,
        inventoryItemId: readInt(json['inventoryItemId']) ?? 0,
        itemName: readString(json['itemName']),
        warehouseId: readInt(json['warehouseId']) ?? 0,
        warehouseName: readString(json['warehouseName']),
        receivedUnit: readString(json['receivedUnit']),
        baseUnit: readString(json['baseUnit']),
        receivedQuantity: readString(json['receivedQuantity']),
        baseQuantity: readString(json['baseQuantity']),
        unitCost: readString(json['unitCost']),
        stockMovementId: readInt(json['stockMovementId']),
      );
}

/// Goods Receipt — Purchasing Phase 2. An independent, auditable physical
/// stock-in record against a posted Supplier Invoice's inventory lines. It
/// carries zero financial/AP effect — the invoice already owns that; a
/// receipt only ever moves physical stock via the backend's existing
/// stock_in pathway (InventoryPostingService), which is intentionally
/// excluded from GL posting.
class PurchaseReceipt {
  const PurchaseReceipt({
    required this.id,
    required this.receiptNumber,
    required this.receiptDate,
    required this.status,
    required this.supplierInvoiceId,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.lineCount,
    required this.allowedActions,
    this.reference,
    this.notes,
    this.invoiceReference,
    this.branchId,
    this.branchName,
    this.createdByName,
    this.postedAt,
    this.createdAt,
    this.lines = const <PurchaseReceiptLine>[],
  });

  final int id;
  final String receiptNumber;
  final String receiptDate;
  /// draft | posted
  final String status;
  final String? reference;
  final String? notes;
  final int supplierInvoiceId;
  final String invoiceNumber;
  final String? invoiceReference;
  final int supplierId;
  final String supplierName;
  final int? branchId;
  final String? branchName;
  final int lineCount;
  final String? createdByName;
  final String? postedAt;
  final String? createdAt;
  final List<String> allowedActions;
  final List<PurchaseReceiptLine> lines;

  bool get isDraft => status == 'draft';

  factory PurchaseReceipt.fromJson(Map<String, dynamic> json) =>
      PurchaseReceipt(
        id: readInt(json['id']) ?? 0,
        receiptNumber: readString(json['receiptNumber']),
        receiptDate: readString(json['receiptDate']),
        status: readString(json['status']),
        reference: readString(json['reference']).isEmpty
            ? null
            : readString(json['reference']),
        notes: readString(json['notes']).isEmpty
            ? null
            : readString(json['notes']),
        supplierInvoiceId: readInt(json['supplierInvoiceId']) ?? 0,
        invoiceNumber: readString(json['invoiceNumber']),
        invoiceReference: readString(json['invoiceReference']).isEmpty
            ? null
            : readString(json['invoiceReference']),
        supplierId: readInt(json['supplierId']) ?? 0,
        supplierName: readString(json['supplierName']),
        branchId: readInt(json['branchId']),
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
        lineCount: readInt(json['lineCount']) ?? 0,
        createdByName: readString(json['createdByName']).isEmpty
            ? null
            : readString(json['createdByName']),
        postedAt: readString(json['postedAt']).isEmpty
            ? null
            : readString(json['postedAt']),
        createdAt: readString(json['createdAt']).isEmpty
            ? null
            : readString(json['createdAt']),
        allowedActions: readStringList(json['allowedActions']),
        lines: readMapList(
          json['lines'],
        ).map(PurchaseReceiptLine.fromJson).toList(growable: false),
      );
}

/// Receipt-history row embedded on a Purchase detail response
/// ("سجل الاستلامات") — a lighter shape than [PurchaseReceipt].
class PurchaseReceiptSummary {
  const PurchaseReceiptSummary({
    required this.id,
    required this.receiptNumber,
    required this.receiptDate,
    required this.status,
    required this.branchName,
    required this.lineCount,
    this.createdByName,
  });

  final int id;
  final String receiptNumber;
  final String receiptDate;
  final String status;
  final String branchName;
  final int lineCount;
  final String? createdByName;

  factory PurchaseReceiptSummary.fromJson(Map<String, dynamic> json) =>
      PurchaseReceiptSummary(
        id: readInt(json['id']) ?? 0,
        receiptNumber: readString(json['receiptNumber']),
        receiptDate: readString(json['receiptDate']),
        status: readString(json['status']),
        branchName: readString(json['branchName']),
        lineCount: readInt(json['lineCount']) ?? 0,
        createdByName: readString(json['createdByName']).isEmpty
            ? null
            : readString(json['createdByName']),
      );
}

class PurchasePayment {
  const PurchasePayment({
    required this.paymentId,
    required this.paymentNumber,
    required this.paymentDate,
    required this.status,
    required this.amount,
  });

  final int paymentId;
  final String paymentNumber;
  final String paymentDate;
  final String status;
  final String amount;

  factory PurchasePayment.fromJson(Map<String, dynamic> json) =>
      PurchasePayment(
        paymentId: readInt(json['paymentId']) ?? 0,
        paymentNumber: readString(json['paymentNumber']),
        paymentDate: readString(json['paymentDate']),
        status: readString(json['status']),
        amount: readString(json['amount']),
      );
}

/// A Purchasing Center row/detail. This is a READ shape of the existing
/// Supplier Invoice domain (`GET /finance/purchases[/:id]`) — creating,
/// editing, posting, and reversing all still go through the pre-existing
/// `finance/supplier-invoices` endpoints (see PurchasingRepository). There is
/// no separate Purchase Invoice source of truth.
class PurchaseInvoice {
  const PurchaseInvoice({
    required this.id,
    required this.internalReference,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.invoiceDate,
    required this.dueDate,
    required this.purchaseType,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.documentStatus,
    required this.paymentStatus,
    required this.status,
    required this.isOverdue,
    this.receiptStatus = 'not_applicable',
    this.branchId,
    this.branchName,
    this.invoiceTypeId,
    this.invoiceTypeName,
    this.invoiceGroupName,
    this.debitAccountId,
    this.debitAccountCode,
    this.debitAccountName,
    this.description,
    this.notes,
    this.createdByName,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.postedAt,
    this.createdAt,
    this.allowedActions = const <String>[],
    this.lines = const <PurchaseInvoiceLine>[],
    this.payments = const <PurchasePayment>[],
    this.receipts = const <PurchaseReceiptSummary>[],
  });

  final int id;
  final String internalReference;
  final String invoiceNumber;
  final int supplierId;
  final String supplierName;
  final int? branchId;
  final String? branchName;
  final String invoiceDate;
  final String dueDate;
  /// inventory | expense | asset | other — derived server-side from the
  /// invoice's lines when present, else its legacy header invoice type.
  final String purchaseType;
  final int? invoiceTypeId;
  final String? invoiceTypeName;
  final String? invoiceGroupName;
  final int? debitAccountId;
  final String? debitAccountCode;
  final String? debitAccountName;
  final String subtotal;
  final String taxAmount;
  final String totalAmount;
  final String paidAmount;
  final String remainingAmount;
  /// draft | posted | cancelled
  final String documentStatus;
  /// not_applicable | unpaid | partial | paid
  final String paymentStatus;
  /// not_applicable | not_received | partially_received | received —
  /// completely independent from paymentStatus, maintained by
  /// PurchaseReceivingService as Goods Receipts are posted.
  final String receiptStatus;
  final String status;
  final bool isOverdue;
  final String? description;
  final String? notes;
  final String? createdByName;
  final int? journalEntryId;
  final int? reversalJournalEntryId;
  final String? postedAt;
  final String? createdAt;
  final List<String> allowedActions;
  final List<PurchaseInvoiceLine> lines;
  final List<PurchasePayment> payments;
  final List<PurchaseReceiptSummary> receipts;

  bool get isDraft => documentStatus == 'draft';
  bool get hasInventoryLines => lines.any((PurchaseInvoiceLine l) => l.isInventory);
  bool get canReceive => allowedActions.contains('receive');

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) =>
      PurchaseInvoice(
        id: readInt(json['id']) ?? 0,
        internalReference: readString(json['internalReference']),
        invoiceNumber: readString(json['invoiceNumber']),
        supplierId: readInt(json['supplierId']) ?? 0,
        supplierName: readString(json['supplierName']),
        branchId: readInt(json['branchId']),
        branchName: readString(json['branchName']).isEmpty
            ? null
            : readString(json['branchName']),
        invoiceDate: readString(json['invoiceDate']),
        dueDate: readString(json['dueDate']),
        purchaseType: readString(json['purchaseType']),
        invoiceTypeId: readInt(json['invoiceTypeId']),
        invoiceTypeName: readString(json['invoiceTypeName']).isEmpty
            ? null
            : readString(json['invoiceTypeName']),
        invoiceGroupName: readString(json['invoiceGroupName']).isEmpty
            ? null
            : readString(json['invoiceGroupName']),
        debitAccountId: readInt(json['debitAccountId']),
        debitAccountCode: readString(json['debitAccountCode']).isEmpty
            ? null
            : readString(json['debitAccountCode']),
        debitAccountName: readString(json['debitAccountName']).isEmpty
            ? null
            : readString(json['debitAccountName']),
        subtotal: readString(json['subtotal']),
        taxAmount: readString(json['taxAmount']),
        totalAmount: readString(json['totalAmount']),
        paidAmount: readString(json['paidAmount'], fallback: '0.00'),
        remainingAmount: readString(json['remainingAmount']),
        documentStatus: readString(json['documentStatus']),
        paymentStatus: readString(json['paymentStatus']),
        receiptStatus: readString(
          json['receiptStatus'],
          fallback: 'not_applicable',
        ),
        status: readString(json['status']),
        isOverdue: readBool(json['isOverdue']),
        description: readString(json['description']).isEmpty
            ? null
            : readString(json['description']),
        notes: readString(json['notes']).isEmpty
            ? null
            : readString(json['notes']),
        createdByName: readString(json['createdByName']).isEmpty
            ? null
            : readString(json['createdByName']),
        journalEntryId: readInt(json['journalEntryId']),
        reversalJournalEntryId: readInt(json['reversalJournalEntryId']),
        postedAt: readString(json['postedAt']).isEmpty
            ? null
            : readString(json['postedAt']),
        createdAt: readString(json['createdAt']).isEmpty
            ? null
            : readString(json['createdAt']),
        allowedActions: readStringList(json['allowedActions']),
        lines: readMapList(
          json['lines'],
        ).map(PurchaseInvoiceLine.fromJson).toList(growable: false),
        payments: readMapList(
          json['payments'],
        ).map(PurchasePayment.fromJson).toList(growable: false),
        receipts: readMapList(
          json['receipts'],
        ).map(PurchaseReceiptSummary.fromJson).toList(growable: false),
      );
}
