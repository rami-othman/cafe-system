<?php

namespace App\Domain\Manufacturing;

use RuntimeException;

final class ManufacturingDomainException extends RuntimeException
{
    public function __construct(public readonly string $domainCode, string $message, public readonly int $status = 422, public readonly array $meta = [])
    {
        parent::__construct($message);
    }

    public static function recipeNotFound(): self
    {
        return new self('MANUFACTURING_RECIPE_NOT_FOUND', 'Manufacturing recipe not found.', 404);
    }

    public static function recipeInactive(): self
    {
        return new self('RECIPE_INACTIVE', 'This recipe is not active.', 422);
    }

    public static function itemInactive(string $itemName): self
    {
        return new self('ITEM_INACTIVE', "Item \"$itemName\" is not active.", 422);
    }

    public static function missingUnitConversion(string $itemName, string $fromUnit, string $toUnit): self
    {
        return new self('MISSING_UNIT_CONVERSION', "No active conversion exists from $fromUnit to $toUnit for \"$itemName\".", 422);
    }

    public static function circularRecipe(): self
    {
        return new self('CIRCULAR_RECIPE', 'This recipe would create a circular manufacturing dependency.', 422);
    }

    public static function warehouseNotAllowed(): self
    {
        return new self('WAREHOUSE_NOT_ALLOWED', 'The selected warehouse is not allowed for this action.', 403);
    }

    public static function insufficientStock(string $itemName, string $shortBy, string $unit): self
    {
        return new self('INSUFFICIENT_STOCK', "Insufficient stock of \"$itemName\" (short by $shortBy $unit).", 422, ['itemName' => $itemName, 'shortBy' => $shortBy, 'unit' => $unit]);
    }

    public static function invalidActualOutput(): self
    {
        return new self('INVALID_ACTUAL_OUTPUT', 'Actual output quantity must be greater than zero.', 422);
    }

    public static function draftNotFound(): self
    {
        return new self('PRODUCTION_DRAFT_NOT_FOUND', 'Production draft not found or already completed.', 404);
    }

    public static function alreadyCompleted(): self
    {
        return new self('PRODUCTION_ALREADY_COMPLETED', 'This production order has already been completed.', 409);
    }

    public static function alreadyReversed(): self
    {
        return new self('PRODUCTION_ALREADY_REVERSED', 'This production order has already been reversed.', 409);
    }

    public static function notReversible(int $producedQty, int $remainingQty, int $consumedQty): self
    {
        return new self('PRODUCTION_NOT_REVERSIBLE', 'This production can no longer be reversed — the output has been fully consumed or sold.', 409, [
            'producedQty' => $producedQty, 'remainingQty' => $remainingQty, 'consumedQty' => $consumedQty,
        ]);
    }

    public static function costUnavailable(string $itemName): self
    {
        return new self('COST_UNAVAILABLE', "Cost is not available for \"$itemName\".", 422);
    }

    public static function duplicateIngredient(string $itemName): self
    {
        return new self('DUPLICATE_INGREDIENT', "\"$itemName\" is already an ingredient in this recipe.", 422);
    }

    public static function validationFailed(string $field, string $message): self
    {
        return new self('MANUFACTURING_VALIDATION_FAILED', $message, 422, ['field' => $field]);
    }

    public static function idempotencyConflict(): self
    {
        return new self('MANUFACTURING_IDEMPOTENCY_CONFLICT', 'This idempotency key was already used for a different request.', 409);
    }

    public static function conversionSameItem(): self
    {
        return new self('CONVERSION_SAME_ITEM', 'Source and target items must be different.', 422);
    }

    public static function conversionNotReversible(): self
    {
        return new self('CONVERSION_NOT_REVERSIBLE', 'This conversion can no longer be reversed.', 409);
    }
}
