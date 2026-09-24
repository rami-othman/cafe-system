<?php

namespace App\Support;

/**
 * Turns Laravel's already-translated validation messages into a
 * client-safe shape: indexed array paths such as "lines.2.unitCost" get a
 * 1-based, Arabic, human position prefix ("البند 3: ...") instead of the
 * raw technical path leaking into the message text. Field keys themselves
 * are left untouched so API clients can still match on them.
 */
final class ValidationErrorPresenter
{
    /** Arabic label for each indexed collection this app validates. */
    private const COLLECTION_LABELS = [
        'lines' => 'البند',
        'allocations' => 'التوزيع',
        'charges' => 'البند',
        'items' => 'العنصر',
        'materials' => 'المادة',
        'ingredients' => 'المكون',
        'components' => 'المكون',
        'barCountLines' => 'بند الجرد',
        'managerialCosts' => 'التكلفة',
        'phones' => 'رقم الهاتف',
        'distributionLines' => 'بند التوزيع',
        'variants' => 'النوع',
        'options' => 'الخيار',
        'placements' => 'الموضع',
        'assignments' => 'التخصيص',
        'overrides' => 'الاستثناء',
        'rules' => 'القاعدة',
        'groups' => 'المجموعة',
        'selectedOptions' => 'الخيار المحدد',
        'materialOverrides' => 'تعديل المادة',
    ];

    /** Fallback label for an indexed collection not listed above. */
    private const DEFAULT_COLLECTION_LABEL = 'العنصر';

    /**
     * @param  array<string, array<int, string>>  $messages  field => [messages], as returned by
     *                                                        Validator::errors()->messages()
     * @return array<string, array<int, string>>
     */
    public static function present(array $messages): array
    {
        $result = [];
        foreach ($messages as $field => $fieldMessages) {
            $prefix = self::indexPrefix($field);
            $result[$field] = $prefix === null
                ? $fieldMessages
                : array_map(static fn (string $message): string => $prefix.$message, $fieldMessages);
        }

        return $result;
    }

    private static function indexPrefix(string $field): ?string
    {
        if (! preg_match('/^([a-zA-Z][a-zA-Z0-9_]*)\.(\d+)\./', $field, $match)) {
            return null;
        }

        $label = self::COLLECTION_LABELS[$match[1]] ?? self::DEFAULT_COLLECTION_LABEL;
        $humanIndex = ((int) $match[2]) + 1;

        return "{$label} {$humanIndex}: ";
    }
}
