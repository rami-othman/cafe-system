import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';

void main() {
  group('Supplier.fromJson', () {
    test('parses a full supplier profile payload', () {
      final Supplier supplier = Supplier.fromJson(<String, dynamic>{
        'id': 3,
        'supplierNumber': 'SUP-00003',
        'name': 'Acme Roasters',
        'phone': '0999',
        'email': 'a@acme.test',
        'address': '123 Street',
        'contactPerson': 'Jane',
        'taxNumber': 'TX-1',
        'paymentTermsDays': 30,
        'notes': 'Reliable',
        'isActive': true,
        'outstandingBalance': '800.00',
        'overdueBalance': '200.00',
        'openInvoiceCount': 2,
        'lastInvoiceDate': '2026-08-20',
        'totalInvoiced': '1500.00',
        'totalPaid': '700.00',
      });

      expect(supplier.id, 3);
      expect(supplier.supplierNumber, 'SUP-00003');
      expect(supplier.outstandingBalance, '800.00');
      expect(supplier.overdueBalance, '200.00');
      expect(supplier.openInvoiceCount, 2);
      expect(supplier.totalInvoiced, '1500.00');
      expect(supplier.totalPaid, '700.00');
    });

    test('defaults balances to zero and optional fields to null when absent', () {
      final Supplier supplier = Supplier.fromJson(<String, dynamic>{
        'id': 1,
        'supplierNumber': 'SUP-00001',
        'name': 'Minimal Supplier',
        'isActive': false,
      });

      expect(supplier.outstandingBalance, '0.00');
      expect(supplier.overdueBalance, '0.00');
      expect(supplier.openInvoiceCount, 0);
      expect(supplier.lastInvoiceDate, isNull);
      expect(supplier.totalInvoiced, isNull);
      expect(supplier.isActive, isFalse);
    });
  });

  group('SupplierInvoice.fromJson', () {
    test('parses status, overdue flag, and remaining amount', () {
      final SupplierInvoice invoice = SupplierInvoice.fromJson(<String, dynamic>{
        'id': 10,
        'internalReference': 'AP-000010',
        'invoiceNumber': 'INV-777',
        'supplierId': 3,
        'supplierName': 'Acme Roasters',
        'invoiceDate': '2026-08-01',
        'dueDate': '2026-08-10',
        'invoiceType': 'expense',
        'expenseCategoryId': 4,
        'expenseCategoryName': 'Rent',
        'debitAccountId': 12,
        'debitAccountCode': '6100',
        'subtotal': '500.00',
        'taxAmount': '0.00',
        'totalAmount': '500.00',
        'remainingAmount': '300.00',
        'status': 'partially_paid',
        'isOverdue': true,
        'journalEntryId': 55,
      });

      expect(invoice.internalReference, 'AP-000010');
      expect(invoice.status, 'partially_paid');
      expect(invoice.isOverdue, isTrue);
      expect(invoice.remainingAmount, '300.00');
      expect(invoice.journalEntryId, 55);
      expect(invoice.reversalJournalEntryId, isNull);
    });
  });

  group('SupplierPayment.fromJson', () {
    test('parses allocations for a multi-invoice payment', () {
      final SupplierPayment payment = SupplierPayment.fromJson(<String, dynamic>{
        'id': 7,
        'paymentNumber': 'SPAY-000007',
        'supplierId': 3,
        'supplierName': 'Acme Roasters',
        'paymentDate': '2026-08-21',
        'amount': '600.00',
        'paymentMethodName': 'Cash',
        'financialLocationName': 'Cash Drawer',
        'status': 'posted',
        'allocations': <Map<String, dynamic>>[
          <String, dynamic>{'invoiceId': 1, 'invoiceReference': 'AP-000001', 'amount': '300.00'},
          <String, dynamic>{'invoiceId': 2, 'invoiceReference': 'AP-000002', 'amount': '300.00'},
        ],
      });

      expect(payment.allocations, hasLength(2));
      expect(payment.allocations.first.invoiceReference, 'AP-000001');
      expect(payment.allocations.last.amount, '300.00');
      expect(payment.status, 'posted');
    });
  });

  group('SupplierStatementLine.fromJson', () {
    test('parses a running-balance line', () {
      final SupplierStatementLine line = SupplierStatementLine.fromJson(<String, dynamic>{
        'date': '2026-08-21',
        'type': 'invoice',
        'reference': 'AP-000001',
        'debit': '0.00',
        'credit': '1000.00',
        'runningBalance': '1000.00',
      });

      expect(line.type, 'invoice');
      expect(line.credit, '1000.00');
      expect(line.runningBalance, '1000.00');
    });
  });
}
