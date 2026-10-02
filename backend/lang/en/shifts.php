<?php

/*
 * Shift / cash drawer lifecycle messages (A2). Keys are shared with
 * lang/ar/shifts.php; the API locale is chosen by SetLocaleFromRequest
 * (X-App-Locale, default Arabic).
 */
return [
    'historical_busy' => 'Cash or inventory is being updated concurrently. Reload the preview and retry closing.',
    'invalid_closing_date' => 'Closing date must be between the shift opening date and today in the branch timezone.',
    'historical_bar_incomplete' => 'The inventory ledger does not reconcile to the current stock balance; historical stock cannot be reconstructed.',
    'historical_bar_adjusted' => 'A later stock-count adjustment requires review before a historical count can be accepted.',
    'historical_transfer_insufficient' => 'Current drawer cash is insufficient to transfer the selected period proceeds.',
    'historical_reversed_settlement' => 'An earlier settlement was reversed after the selected date and requires review before splitting.',
    'historical_multiple_bars' => 'Historical closing requires separate counts for the multiple mandatory bar templates.',
    'historical_split_payment' => 'An order has receipts before the boundary but completed later. Review its receipt allocation before splitting.',
    'historical_preview_required' => 'Load the selected date closing preview and review cash and stock counts.',
    'historical_preview_changed' => 'Movements changed after the preview. Reload and review the counts before confirming.',
    'historical_retry_changed' => 'This period was already closed with different inputs. Review its closing report.',
    'historical_invalid_basis' => 'Choose a recorded period-end count or a count performed now.',
    'branch_unavailable' => 'The branch is unavailable or inactive.',
    'drawer_not_configured' => 'A shift cannot be opened because this branch has no POS cash drawer configured.',
    'drawer_invalid' => 'The branch POS cash drawer configuration is incomplete. It must be an active cash drawer that belongs to this branch.',
    'destination_not_configured' => 'A shift cannot be opened because this branch has no shift close destination configured.',
    'destination_invalid' => 'The shift close destination must be an active cash location of this tenant, either global or belonging to this branch.',
    'destination_same_as_drawer' => 'The shift close destination cannot be the POS cash drawer itself.',
    'destination_is_drawer' => 'The shift close destination cannot be another physical cash drawer; choose a safe or non-drawer cash location.',
    'closing_float_invalid' => 'The closing float must be zero or greater.',
    'drawer_has_open_shift' => 'This cash drawer already has an open shift.',
    'opening_cash_mismatch' => 'Counted opening cash must match the posted drawer ledger balance (:ledger). Post any safe-to-drawer transfer before opening the shift.',
    'shift_not_found' => 'Shift not found.',
    'shift_not_open' => 'Only an open shift can be closed.',
    'only_owner_can_close' => 'Only the shift owner can close this shift.',
    'bar_check_required' => 'Complete the required bar check before closing the shift.',
    'counted_differs_from_expected' => 'Counted cash differs from expected cash. Recount and correct missing cash movements; a manager-approved variance policy is required to close with a difference.',
    'counted_below_float' => 'Counted cash must cover the configured closing float.',
    'close_configuration_missing' => 'This shift has no valid drawer and close destination. Adopt the current branch close configuration before closing it.',
    'close_destination_invalid' => 'The close destination must be an active cash location for this tenant, different from the shift drawer.',
    'drawer_ledger_mismatch' => 'The drawer ledger balance does not match counted cash. Reconcile the opening cash and posted cash movements before closing.',
    'close_transfer_exists' => 'A close transfer is already recorded for this shift.',
    'variance_account_missing' => 'No cash shortage account configured. Set one in branch settings or activate account 6180.',
    'over_account_missing' => 'No cash overage account configured. Set one in branch settings or activate account 4040.',
    'difference_reason_required' => 'Counted cash differs from expected cash. Choose a reason for the difference so it can be posted to the cash variance account.',
];
