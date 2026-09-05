import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/finance_inventory_setup/models/finance_setup_models.dart';

void main() {
  group('ExpenseCategory.fromJson', () {
    test('parses every backend field', () {
      final ExpenseCategory category = ExpenseCategory.fromJson(<String, dynamic>{
        'id': 4,
        'code': 'RENT',
        'name': 'Rent',
        'financialAccountId': 12,
        'financialAccountCode': '6100',
        'financialAccountName': 'Rent Expense',
        'isActive': true,
        'sortOrder': 3,
      });

      expect(category.id, 4);
      expect(category.code, 'RENT');
      expect(category.name, 'Rent');
      expect(category.financialAccountId, 12);
      expect(category.financialAccountCode, '6100');
      expect(category.financialAccountName, 'Rent Expense');
      expect(category.isActive, isTrue);
      expect(category.sortOrder, 3);
    });

    test('defaults sortOrder and financialAccountName when absent', () {
      final ExpenseCategory category = ExpenseCategory.fromJson(<String, dynamic>{
        'id': 1,
        'code': 'MISC',
        'name': 'Misc',
        'financialAccountId': 5,
        'financialAccountCode': '6190',
        'isActive': false,
      });

      expect(category.sortOrder, 0);
      expect(category.financialAccountName, isNull);
      expect(category.isActive, isFalse);
    });
  });

  group('ExpenseRecord.fromJson', () {
    test('parses a fully populated paid-and-approved record', () {
      final ExpenseRecord expense = ExpenseRecord.fromJson(<String, dynamic>{
        'id': 10,
        'expenseNumber': 'EXP-000010',
        'branchId': 2,
        'branchName': 'Main Branch',
        'expenseCategoryId': 4,
        'expenseCategoryCode': 'RENT',
        'expenseCategoryName': 'Rent',
        'amount': '250.00',
        'taxAmount': '25.00',
        'totalAmount': '275.00',
        'expenseDate': '2026-08-20',
        'description': 'August rent',
        'notes': 'Paid early',
        'status': 'paid',
        'paymentStatus': 'paid',
        'paymentMethodId': 1,
        'paymentMethodName': 'Cash',
        'financialLocationId': 3,
        'financialLocationName': 'Cash Drawer',
        'paidAt': '2026-08-21',
        'journalEntryId': 99,
        'reversalJournalEntryId': null,
        'createdByName': 'Finance Owner',
        'approvedAt': '2026-08-20T10:00:00Z',
        'rejectedAt': null,
        'rejectionReason': null,
        'createdAt': '2026-08-19T09:00:00Z',
        'updatedAt': '2026-08-21T08:00:00Z',
      });

      expect(expense.id, 10);
      expect(expense.expenseNumber, 'EXP-000010');
      expect(expense.branchName, 'Main Branch');
      expect(expense.expenseCategoryCode, 'RENT');
      expect(expense.amount, '250.00');
      expect(expense.taxAmount, '25.00');
      expect(expense.totalAmount, '275.00');
      expect(expense.status, 'paid');
      expect(expense.paymentStatus, 'paid');
      expect(expense.paymentMethodName, 'Cash');
      expect(expense.financialLocationName, 'Cash Drawer');
      expect(expense.journalEntryId, 99);
      expect(expense.reversalJournalEntryId, isNull);
      expect(expense.createdByName, 'Finance Owner');
      expect(expense.approvedAt, '2026-08-20T10:00:00Z');
      expect(expense.rejectedAt, isNull);
      expect(expense.rejectionReason, isNull);
      expect(expense.createdAt, '2026-08-19T09:00:00Z');
      expect(expense.updatedAt, '2026-08-21T08:00:00Z');
    });

    test('treats a draft record with no branch/payment data as all-null optionals', () {
      final ExpenseRecord expense = ExpenseRecord.fromJson(<String, dynamic>{
        'id': 1,
        'expenseNumber': 'EXP-000001',
        'expenseCategoryId': 4,
        'expenseCategoryName': 'Rent',
        'amount': '100.00',
        'taxAmount': '0.00',
        'totalAmount': '100.00',
        'expenseDate': '2026-08-20',
        'description': 'Draft rent',
        'status': 'draft',
        'paymentStatus': 'unpaid',
      });

      expect(expense.branchId, isNull);
      expect(expense.branchName, isNull);
      expect(expense.paymentMethodName, isNull);
      expect(expense.financialLocationName, isNull);
      expect(expense.journalEntryId, isNull);
      expect(expense.createdByName, isNull);
      expect(expense.approvedAt, isNull);
      expect(expense.status, 'draft');
      expect(expense.paymentStatus, 'unpaid');
    });
  });
}
