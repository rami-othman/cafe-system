# Direct purchase flow audit and implementation

## Root cause

`SupplierInvoiceService::post` creates the accounts payable journal but does not move stock. `PurchaseReceivingService::post` owns stock movements and warehouse balance/WAC updates. The purchasing-specific posting route already called both services in one transaction, but it always paid the full outstanding amount and did not persist a receive-later choice. The purchase form used that route after saving a draft; the detail screen exposed manual receipt whenever any quantity remained.

## New rule

## Old UX versus new UX

Previously, the user posted a supplier invoice, then had to open a separate stock receipt, choose a warehouse, enter quantities, and confirm receipt. A normal direct purchase now uses one purchase form: supplier, items, quantities and prices, warehouse, discounts and charges, and amount paid now. Posting the invoice automatically creates and posts its receipt and stock movement, records any optional payment, and finishes the workflow. No second receipt screen or confirmation is required.

For an explicit receive-later purchase, invoice posting creates no stock movement. The detail shows that receipt is pending and offers the dedicated receipt action. Later manual and partial receipts remain available.

New purchase forms send `receiptMode=immediate` by default for inventory lines. `receive_later` is explicit and retains the dedicated receipt screen, partial deliveries, and multiple receipts. Historical rows have `receipt_mode=NULL`; no migration updates their stock. A previously posted historical invoice remains pending receipt even if the purchase posting route is called again. The generic supplier-invoice posting endpoint delegates immediate-mode invoices to purchase posting with zero payment so this endpoint cannot leave a newly marked direct purchase financially posted without stock.

Purchase posting holds the invoice lock and performs invoice posting, receipt creation/posting, and an optional supplier payment/voucher in one database transaction. A zero payment does not require a cash source or shift. Receipt lines use the invoice line warehouse; `PurchaseReceivingService` remains the sole stock movement writer. Existing idempotency keys on invoice, receipt, receipt line, and payment prevent duplicate effects. The invoice, receipt, receipt line, and stock movement references remain linked.

The form now captures the amount paid and receipt mode. Immediate purchases select their destination warehouse once and apply it to every invoice line; receive-later purchases retain per-line warehouse choice for split deliveries. The purchase list opens on invoice rows and shows warehouse plus independent document, payment, and inventory statuses. The detail screen shows the same distinct statuses and preserves the receipt history. Direct receipts have no receive action because their remaining quantity is zero.

## Deliberate limit

A posted receipt has no supported reversal workflow. Cancellation of a received invoice is blocked until such a reversal exists, preventing a cancelled payable from leaving unexplained stock. The purchase detail explains this in Arabic. Receive-later invoices with no posted receipts retain the normal reversal path. A purchase that spans multiple warehouses shows "متعدد المخازن" in the list and detail; its receipt lines retain their individual destinations.

## Release verification on 2026-09-19

The receipt-mode migration now uses `2026_09_19_000001_add_purchase_receipt_mode.php`. Its predecessor creates the purchase receipt tables on September 13; the September 24 and 25 purchase finance migrations do not depend on `receipt_mode`. The focused backend suite migrated its test database and passed 31 tests / 362 assertions. Flutter purchasing tests passed 33 tests, and `flutter analyze --no-pub` reported no issues. The broad related backend run had 94 passes and 9 failures in existing Phase 1 purchasing, supplier cash payment, and bar-check expectations. A live Flutter walkthrough of all four scenarios remains outstanding because no inspectable app surface was available. Staging readiness therefore remains blocked.
