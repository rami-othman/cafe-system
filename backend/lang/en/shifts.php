<?php

/*
 * Shift / cash drawer lifecycle messages (A2). Keys are shared with
 * lang/ar/shifts.php; the API locale is chosen by SetLocaleFromRequest
 * (X-App-Locale, default Arabic).
 */
return [
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
];
