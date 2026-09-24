<?php

namespace Tests\Unit;

use App\Http\Controllers\Api\ShiftController;
use Illuminate\Database\QueryException;
use PDOException;
use PHPUnit\Framework\TestCase;

/**
 * 6A — only the shifts_one_open_per_location unique-index conflict may be
 * remapped to the friendly "drawer already has an open shift" error. Any
 * other 23505 (unrelated unique constraint) must propagate unchanged, never
 * be swallowed or misreported as a drawer conflict.
 */
final class ShiftOpenUniqueViolationTest extends TestCase
{
    public function test_the_shift_drawer_unique_index_violation_is_recognized(): void
    {
        $exception = $this->queryException('23505', 'SQLSTATE[23505]: Unique violation: 7 ERROR: duplicate key value violates unique constraint "shifts_one_open_per_location"');

        $this->assertTrue(ShiftController::isOpenShiftUniqueViolation($exception));
    }

    public function test_an_unrelated_unique_constraint_violation_is_not_recognized(): void
    {
        $exception = $this->queryException('23505', 'SQLSTATE[23505]: Unique violation: 7 ERROR: duplicate key value violates unique constraint "users_email_unique"');

        $this->assertFalse(ShiftController::isOpenShiftUniqueViolation($exception));
    }

    public function test_a_non_unique_violation_sqlstate_is_not_recognized_even_if_the_message_mentions_the_index(): void
    {
        // Defence in depth: the sqlstate must also be 23505, not just the message text.
        $exception = $this->queryException('23514', 'SQLSTATE[23514]: Check violation near shifts_one_open_per_location');

        $this->assertFalse(ShiftController::isOpenShiftUniqueViolation($exception));
    }

    private function queryException(string $sqlState, string $message): QueryException
    {
        $previous = new PDOException($message);
        $previous->errorInfo = [$sqlState, 7, $message];

        return new QueryException('pgsql', 'insert into "shifts" ...', [], $previous);
    }
}
