# Existing test failures at factory acceptance

Compared with clean phase-2 commit 583de91 using independent application/vendor copies and identical dependencies. Final Laravel: 970 passed, 36 failed, one skipped; baseline: 959 passed, 37 failed, one skipped. All 36 final failure names exist in the baseline; zero new failing cases. The canonical finance permission route-map failure was corrected. Full suites are not green.

## Laravel failures

| Test case | Observed cause / fixture limitation |
|---|---|
| `Tests.Feature.AuthPhaseFourOperationalCutoverTest::test_assigned_branch_list_and_shift_owner_are_authenticated` |  يرجى تصحيح البيانات المدخلة. cashSource: لا يمكن فتح الوردية لأن صندوق نقطة البيع غير محدد لهذا الفرع. shiftCloseDestinationFinancialLocationId: لا يمكن فتح الوردية لأن وجهة تحويل النقدية عند إغلاق الوردية غير محددة لهذا الفرع. |
| `Tests.Feature.AuthPhaseFourOperationalCutoverTest::test_order_payment_and_availability_use_authenticated_actor` | NO_OPEN_SHIFT يجب فتح وردية قبل تنفيذ هذه العملية. shiftId: The order shift has no valid cash drawer. |
| `Tests.Feature.AuthPhaseFourOperationalCutoverTest::test_payment_requires_the_authenticated_users_open_shift_for_the_order_branch` | NO_OPEN_SHIFT يجب فتح وردية قبل تنفيذ هذه العملية. shiftId: The order shift has no valid cash drawer. |
| `Tests.Feature.AuthPhaseOneTest::test_role_aware_login_hashes_tokens_and_returns_session_identity` | Permission-array expectation starts with finance.vouchers.view; actual first permission is finance.cash_sources.view (same baseline difference). |
| `Tests.Feature.Cafe618FinanceOperationsDemoSeederTest::test_it_seeds_service_backed_finance_activity_for_the_normal_demo_tenant_idempotently` | Illuminate\Validation\ValidationException: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.Cafe618PosSalesDemoSeederTest::test_it_creates_idempotent_paid_sales_with_real_inventory_consumption_cogs_and_refunds` | Illuminate\Validation\ValidationException: يوجد وردية مفتوحة بالفعل على صندوق النقدية هذا. |
| `Tests.Feature.Cafe618ReportsDemoSeederTest::test_it_creates_idempotent_report_ready_sales_cash_and_shift_history` | Illuminate\Validation\ValidationException: النقدية الافتتاحية المعدودة يجب أن تساوي الرصيد المرحّل لصندوق النقدية (0.00). رحّل أي تحويل من الخزنة إلى الصندوق قبل فتح الوردية. |
| `Tests.Feature.DiscountRuntimeEligibilityTest::test_zero_percentage_and_fixed_discounts_apply_without_changing_authoritative_totals_and_count_as_usage` | NO_OPEN_SHIFT يجب فتح وردية قبل تنفيذ هذه العملية. shiftId: The order shift has no valid cash drawer. |
| `Tests.Feature.DiscountRuntimeEligibilityTest::test_payment_method_id_is_authoritative_for_discount_eligibility_and_idempotent_retries` | NO_OPEN_SHIFT يجب فتح وردية قبل تنفيذ هذه العملية. shiftId: The order shift has no valid cash drawer. |
| `Tests.Feature.DiscountRuntimeEligibilityTest::test_paid_order_retains_its_discount_snapshot_after_the_policy_changes` | NO_OPEN_SHIFT يجب فتح وردية قبل تنفيذ هذه العملية. shiftId: The order shift has no valid cash drawer. |
| `Tests.Feature.FinanceDashboardBreakdownAndBranchTest::test_expense_breakdown_groups_by_category_with_percentage` | Illuminate\Validation\ValidationException: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.FinanceDashboardBreakdownAndBranchTest::test_expense_breakdown_is_tenant_isolated` | Illuminate\Validation\ValidationException: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.FinanceDashboardExpensesAndApTest::test_only_accounting_effective_paid_expense_is_counted` | Illuminate\Validation\ValidationException: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.FinanceDashboardExpensesAndApTest::test_cash_paid_and_bank_paid_expense_are_each_counted_once_not_twice` | Illuminate\Validation\ValidationException: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.FinanceDashboardSalesAndCogsTest::test_operating_profit_correct_when_data_complete_and_unreliable_when_cogs_incomplete` | Illuminate\Validation\ValidationException: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.FinanceOperationsDemoSeederTest::test_the_connected_finance_demo_is_idempotent_and_closes_its_operational_period` | Illuminate\Validation\ValidationException: The order shift has no valid cash drawer. |
| `Tests.Feature.Phase12AuthorizationApiTest::test_explicit_permissions_drive_non_manager_access_and_no_rows_deny` | Expected a narrow explicit permission list; seeded role now includes expanded finance permissions (same baseline difference). |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_concurrent_different_key_payments_settle_an_order_once` | Failed asserting that actual size 0 matches expected size 1. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_concurrent_same_key_payments_converge_on_one_payment` | Failed asserting that actual size 0 matches expected size 2. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_concurrent_final_discount_usage_is_consumed_once` | Failed asserting that actual size 0 matches expected size 1. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_concurrent_same_customer_daily_limit_one_allows_one_payment_and_one_usage` | Failed asserting that actual size 0 matches expected size 1. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_concurrent_same_customer_daily_limit_two_allows_two_then_rejects_the_third_use` | Failed asserting that actual size 0 matches expected size 2. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_lost_response_retry_of_daily_limited_discount_payment_does_not_consume_a_second_usage` | Failed asserting that false is true. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PreAuthFinancialConcurrencyTest::test_payment_conflict_and_lost_response_retry_have_no_second_effect` | NO_OPEN_SHIFT يجب فتح وردية قبل تنفيذ هذه العملية. shiftId: The order shift has no valid cash drawer. Fixture inserts shifts without financial_location_id; payment workers are rejected by the existing cash-drawer requirement. |
| `Tests.Feature.PurchasingPhase1ApiTest::test_purchasing_center_show_returns_lines_and_related_payments` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.SalesReportingUnionTest::test_pos_plus_manual_union_never_double_counts_revenue_or_cash` |  يرجى تصحيح البيانات المدخلة. financialLocationId: الصندوق المحدد غير متاح لهذا الفرع. |
| `Tests.Feature.SmartSearchApiTest::test_tenant_isolation_is_never_broadened_by_search` | Illuminate\Database\QueryException: SQLSTATE[23502]: Not null violation: 7 ERROR: null value in column "customer_number" of relation "customers" violates not-null constraint |
| `Tests.Feature.SmartSearchApiTest::test_phone_search_ignores_formatting_differences` | Illuminate\Database\QueryException: SQLSTATE[23502]: Not null violation: 7 ERROR: null value in column "customer_number" of relation "customers" violates not-null constraint |
| `Tests.Feature.StagingInitializerTest::test_publication_failure_leaves_committed_base_staging_data_intact` | Fixture expects 3 branches, staging initialization creates 4; same baseline assertion. |
| `Tests.Feature.SupplierAccountsPayableApiTest::test_partial_then_full_payment_updates_status_and_remaining_correctly` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.SupplierAccountsPayableApiTest::test_one_payment_allocates_across_two_invoices_and_supports_the_documented_statement_scenario` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.SupplierAccountsPayableApiTest::test_allocation_across_different_supplier_or_tenant_invoice_is_rejected` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.SupplierAccountsPayableApiTest::test_supplier_payment_idempotency_replay_and_conflict` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.SupplierAccountsPayableApiTest::test_reversing_a_posted_invoice_with_no_allocations_is_allowed_but_blocked_once_allocated` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.SupplierAccountsPayableApiTest::test_reversing_a_supplier_payment_restores_invoice_balance_and_cash` |  يرجى تصحيح البيانات المدخلة. branchId: A branch is required for cash payment. |
| `Tests.Feature.WarehouseConfigurationRepairTest::test_dry_run_does_not_write_and_apply_creates_only_missing_warehouse_without_touching_stock` | RuntimeException: Tenant 19 has no active cash account 1010. |

DiscountRuntimeEligibilityTest: all three failed cases have HTTP 422 / NO_OPEN_SHIFT / "The order shift has no valid cash drawer." in both baseline and final evidence. Cafe cashier acceptance with a real configured drawer passed through shift opening, order, discount, payment and closing. The skipped case is CustomerSearchPaginationTest::test_opt_in_100k_query_plan_benchmark (opt-in benchmark).

## Flutter failures

Final: 1516 passed / 23 failed. Clean phase-2 baseline: 1512 passed / the identical 23 failed case names. No new failing cases.

| Test case | Existing observed failure |
|---|---|
| `test/app/customer_management_routing_test.dart::builds every direct Customer Management route without cached records` | Missing auth/provider fixture and localized hierarchy/title expectations. |
| `test/app/cashier_route_guard_test.dart::cashier cannot open admin/privileged routes by direct navigation` | Expected cashier route destination differs from current dashboard routing. |
| `test/app/cashier_route_guard_test.dart::cashier is routed to the limited Finance workspace` | Expected cashier route destination differs from current dashboard routing. |
| `test/app/customer_management_routing_test.dart::all Customer Management routes keep their localized hierarchy and tab` | Missing auth/provider fixture and localized hierarchy/title expectations. |
| `test/cashier_dashboard_screen_test.dart::a Cashier lands on the operational dashboard, not the till` | Expected dashboard clock/text is absent from the fixture. |
| `test/core/tax_config_test.dart::POS totals and discount preview generate dynamic tax labels` | Dynamic localized tax-label expectation (Tax 7$1%) differs from rendered labels. |
| `test/cashier_inventory_screen_test.dart::sidebar a Cashier sees only the operational destinations` | Expected Finance/Customers sidebar labels are absent in the fixture. |
| `test/cashier_inventory_screen_test.dart::sidebar an Owner sidebar is unchanged` | Expected Finance/Customers sidebar labels are absent in the fixture. |
| `test/features/auth/auth_session_storage_contract_test.dart::preserves owner and granted-manager customer capability through storage` | Stored capability/legacy metadata expectations differ from current session contract. |
| `test/features/auth/auth_session_storage_contract_test.dart::fails closed for ungranted managers, employees, and legacy metadata` | Stored capability/legacy metadata expectations differ from current session contract. |
| `test/features/customer_management/goldens/customer_states_golden_test.dart::state matrix owns web-desktop and mutation state rows` | Existing locale/viewport golden or matrix coverage assertion mismatch. |
| `test/features/customer_management/goldens/customer_dialogs_golden_test.dart::customer dialogs own every locale/viewport row` | Existing locale/viewport golden or matrix coverage assertion mismatch. |
| `test/features/customer_management/goldens/customer_group_screens_golden_test.dart::group screens own every ready locale/viewport row` | Existing locale/viewport golden or matrix coverage assertion mismatch. |
| `test/features/customer_management/goldens/customer_screens_golden_test.dart::customer screens own every ready locale/viewport row` | Existing locale/viewport golden or matrix coverage assertion mismatch. |
| `test/features/finance_inventory_setup/views/cash_banks_screen_test.dart::create account dialog validates required fields then submits the real payload` | Account form fixture lacks Provider<AuthSessionCubit>. |
| `test/features/orders/widgets/orders_payment_screen_test.dart::Pay loads authoritative outstanding amount before opening dialog` | Authoritative payment dialog/order text or request assertion is not met by the widget fixture. |
| `test/features/orders/widgets/orders_payment_screen_test.dart::double Pay taps make one authoritative preparation request` | Authoritative payment dialog/order text or request assertion is not met by the widget fixture. |
| `test/features/orders/widgets/orders_payment_screen_test.dart::details-panel Pay uses the same authoritative workflow` | Authoritative payment dialog/order text or request assertion is not met by the widget fixture. |
| `test/features/sales/sales_phase_three_test.dart::CustomerPaymentDialog auto-allocates oldest-due-first and posts a balanced allocation` | Customer-payment dialog invoice/allocation widget expectations are not met (including missing SI-1 row). |
| `test/features/sales/sales_phase_three_test.dart::CustomerPaymentDialog blocks posting while any amount is left unallocated` | Customer-payment dialog invoice/allocation widget expectations are not met (including missing SI-1 row). |
| `test/features/shift/shift_overview_smoke_test.dart::shift overview loads an open shift and shows the closing action` | Fixture lacks Provider<PosCubit> required by the shift listener. |
| `test/features/shift/shift_closing_flow_test.dart::closes a balanced shift through all five wizard steps` | Fixture lacks Provider<PosCubit> required by the shift listener. |
| `test/orders_screen_test.dart::opens Orders from sidebar and hides POS cart panel` | Shell/auth/provider fixture does not expose the expected Orders navigation state. |

Raw logs: E:/cafe6.18/docs/FACTORY_BACKEND_TEST_RESULTS_VERIFIED.txt, FACTORY_BACKEND_BASELINE_RESULTS_VALID.txt, FACTORY_FLUTTER_TEST_RESULTS_FINAL.txt, FACTORY_FLUTTER_BASELINE_RESULTS.txt. Generated JUnit/JSON comparison artifacts remain outside the proposed commit.
