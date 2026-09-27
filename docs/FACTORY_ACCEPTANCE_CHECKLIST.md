# Factory acceptance

Run against local Docker `cafe_system_618`. Keep factory sales and cafe purchases as separate documents; enter prices independently.

1. Sign in as `factory.demo@cafe618.test` / `FactoryDemo123`. Verify factory opens, cafe destinations and shift badge are absent, and branch choices contain only assigned factories.
2. Open materials. Verify only factory materials, quantity, average cost and stock value. Toggle in-stock-only and search. Create a material without choosing a warehouse; save, edit and return stay under `/manufacturing`.
3. Open a finished product. Check balances, recipe usage, purchases, paginated movement history and production batches. Follow related documents and return without switching to cafe inventory.
4. Create a recipe using the selected factory's output and ingredients. Search components, request another page, inspect available quantity/unit, simulate an API failure and retry. Preview and produce; check raw stock decreases and output WAC equals consumed material cost.
5. Purchase raw materials inside manufacturing. Branch/default warehouse remain locked. Post/receive and pay from the factory cash location without opening a POS shift. Check purchase and receipt back/save/edit navigation.
6. Sell one finished unit for a manually chosen price. Check finished stock decreases once, raw ingredients remain unchanged, factory revenue/COGS are posted, and no POS shift/order appears.
7. Verify cash/banks, journals, documents, expenses, transactions, reconciliations and reports expose only factory branches, excluding global Main Safe/Cash Drawer. Account ledger totals must agree with the factory journals.
8. As cafe manager, verify cafe finance/inventory work, factory materials/parties are absent and manufacturing is inaccessible. As cashier: open cafe shift, create order, apply eligible discount, pay, close shift. Verify stock, journals and cash reconciliation.
9. As owner, switch cafe/factory data scope and verify lists/forms reload. Try direct foreign material/recipe URLs and mismatched document lines/warehouses; expect 403/404/422, no partial writes.
10. Set up internal parties twice. Factory customers represent cafes; cafe supplier represents factory. Owner can mark/unmark existing parties, other roles cannot. Check internal badges and counterpart branch in factory sales selection.
11. Produce → sell on credit to internal cafe customer → independently purchase into a cafe material → pay supplier from cafe drawer → collect customer payment into factory drawer. Check each debt reaches zero, no warehouse transfer exists and no factory shift was needed.
12. Open owner consolidated financial reports with internal movements hidden, then enable them. Revenue/AP/AR must change by the internal documents; selected branch reports retain their internal documents in both states. Verify internal reconciliation exposes any difference.
13. Create another factory and assign another manager. Check items, recipes, production, reports and parties stay isolated. Backfill previews must refuse ambiguous recipe/item ownership without writing anything.

Automated evidence and known failures are recorded in `E:\cafe6.18\docs\FACTORY_PROGRESS_LOG.md` and the final verification report. This checklist describes manual acceptance; unchecked steps are not claimed as manually performed.
