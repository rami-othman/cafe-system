<?php

namespace Tests\Unit;

use App\Support\DomainErrorMessages;
use App\Support\SafeExceptionResponse;
use App\Support\ValidationErrorPresenter;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class ValidationErrorPresentationUnitTest extends TestCase
{
    public function test_indexed_line_field_gets_one_based_arabic_prefix(): void
    {
        $presented = ValidationErrorPresenter::present([
            'lines.2.unitCost' => ['تكلفة الوحدة غير صالحة.'],
        ]);

        $this->assertStringContainsString('البند 3', $presented['lines.2.unitCost'][0]);
        $this->assertStringNotContainsString('lines.2.unitCost', $presented['lines.2.unitCost'][0]);
    }

    public function test_first_index_maps_to_position_one(): void
    {
        $presented = ValidationErrorPresenter::present(['lines.0.quantity' => ['الكمية مطلوبة.']]);

        $this->assertStringContainsString('البند 1', $presented['lines.0.quantity'][0]);
    }

    public function test_unknown_collection_falls_back_safely(): void
    {
        $presented = ValidationErrorPresenter::present(['weirdThings.3.value' => ['قيمة غير صالحة.']]);

        $this->assertStringContainsString('العنصر 4', $presented['weirdThings.3.value'][0]);
    }

    public function test_non_indexed_field_is_untouched(): void
    {
        $presented = ValidationErrorPresenter::present(['name' => ['الاسم مطلوب.']]);

        $this->assertSame(['الاسم مطلوب.'], $presented['name']);
    }

    public function test_field_keys_are_preserved(): void
    {
        $presented = ValidationErrorPresenter::present(['lines.2.unitCost' => ['x']]);

        $this->assertArrayHasKey('lines.2.unitCost', $presented);
    }

    public function test_domain_error_messages_covers_known_codes_in_arabic(): void
    {
        $message = DomainErrorMessages::forCode('CASH_REFUND_SHIFT_CLOSED');

        $this->assertMatchesRegularExpression('/[\x{0600}-\x{06FF}]/u', $message);
    }

    public function test_domain_error_messages_falls_back_safely_for_unknown_code(): void
    {
        $message = DomainErrorMessages::forCode('SOME_FUTURE_CODE_NOT_YET_MAPPED');

        $this->assertMatchesRegularExpression('/[\x{0600}-\x{06FF}]/u', $message);
        $this->assertStringNotContainsString('SOME_FUTURE_CODE_NOT_YET_MAPPED', $message);
    }

    public function test_safe_exception_response_replaces_unexpected_errors_when_debug_is_off(): void
    {
        $this->assertTrue(SafeExceptionResponse::shouldReplace(new \RuntimeException('db exploded'), false));
    }

    public function test_safe_exception_response_leaves_unexpected_errors_alone_when_debug_is_on(): void
    {
        $this->assertFalse(SafeExceptionResponse::shouldReplace(new \RuntimeException('db exploded'), true));
    }

    public function test_safe_exception_response_never_replaces_validation_exceptions(): void
    {
        $exception = ValidationException::withMessages(['field' => ['bad']]);

        $this->assertFalse(SafeExceptionResponse::shouldReplace($exception, false));
    }

    public function test_safe_exception_response_body_is_generic_arabic(): void
    {
        $body = SafeExceptionResponse::body();

        $this->assertSame('UNEXPECTED_ERROR', $body['code']);
        $this->assertMatchesRegularExpression('/[\x{0600}-\x{06FF}]/u', $body['message']);
    }
}
