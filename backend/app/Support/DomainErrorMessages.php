<?php

namespace App\Support;

/**
 * Arabic display copy for the app's coded domain exceptions
 * (OrderLifecycleException, CustomerDomainException, and the
 * generic DomainException fallback).
 *
 * The original English exception message is still logged — this class only
 * changes what the API client sees. A domainCode with no entry here falls
 * back to a safe generic Arabic message rather than leaking the raw
 * exception text.
 */
final class DomainErrorMessages
{
    private const MESSAGES = [
        // OrderLifecycleException
        'CASH_REFUND_SHIFT_CLOSED' => 'استرداد النقدية بعد إغلاق وردية عملية البيع يتطلب إجراء صرف معتمد.',
        'DISCOUNT_APPLICATION_MODE_UNSUPPORTED' => 'طريقة تطبيق الخصم غير مدعومة.',
        'DISCOUNT_BOGO_UNSUPPORTED' => 'عرض "اشترِ واحصل" غير مدعوم لهذا الخصم.',
        'DISCOUNT_BRANCH_NOT_ELIGIBLE' => 'هذا الخصم غير متاح لهذا الفرع.',
        'DISCOUNT_CHANNEL_NOT_ELIGIBLE' => 'هذا الخصم غير متاح لقناة البيع هذه.',
        'DISCOUNT_CODE_REQUIRED' => 'كود الخصم مطلوب.',
        'DISCOUNT_CUSTOMER_NOT_ELIGIBLE' => 'هذا العميل غير مؤهل لهذا الخصم.',
        'DISCOUNT_CUSTOMER_REQUIRED' => 'يجب تحديد العميل لتطبيق هذا الخصم.',
        'DISCOUNT_DAILY_USAGE_LIMIT_REACHED' => 'تم بلوغ الحد اليومي لاستخدام هذا الخصم.',
        'DISCOUNT_DAY_NOT_ALLOWED' => 'هذا الخصم غير متاح في هذا اليوم.',
        'DISCOUNT_EXPIRED' => 'انتهت صلاحية هذا الخصم.',
        'DISCOUNT_INACTIVE' => 'هذا الخصم غير مفعل حاليًا.',
        'DISCOUNT_ITEMS_NOT_ELIGIBLE' => 'الأصناف المحددة غير مؤهلة لهذا الخصم.',
        'DISCOUNT_MINIMUM_NOT_MET' => 'لم يتم بلوغ الحد الأدنى المطلوب لتطبيق هذا الخصم.',
        'DISCOUNT_NOT_STARTED' => 'لم يبدأ سريان هذا الخصم بعد.',
        'DISCOUNT_PAYMENT_METHOD_NOT_ALLOWED' => 'هذا الخصم غير متاح مع طريقة الدفع المحددة.',
        'DISCOUNT_SELECTION_REQUIRED' => 'يجب تحديد عنصر لتطبيق هذا الخصم.',
        'DISCOUNT_TIME_NOT_ALLOWED' => 'هذا الخصم غير متاح في هذا الوقت.',
        'DISCOUNT_USAGE_LIMIT_REACHED' => 'تم بلوغ الحد الأقصى لاستخدام هذا الخصم.',
        'ORDER_IDEMPOTENCY_CONFLICT' => 'تم استخدام مفتاح العملية هذا مسبقًا لطلب مختلف.',
        'ORDER_NOT_EDITABLE' => 'لا يمكن تعديل هذا الطلب في حالته الحالية.',
        'ORDER_WAREHOUSE_INVALID' => 'المخزن المحدد لهذا الطلب غير صالح.',
        'ORDER_WAREHOUSE_NOT_CONFIGURED' => 'لم يتم إعداد مخزن لهذا الطلب.',
        'PAYMENT_ALREADY_COMPLETED' => 'تم سداد هذا الطلب بالكامل مسبقًا.',
        'PAYMENT_IDEMPOTENCY_CONFLICT' => 'تم استخدام مفتاح العملية هذا مسبقًا لعملية دفع مختلفة.',
        'PAYMENT_METHOD_INVALID' => 'طريقة الدفع المحددة غير صالحة.',
        'POS_WAREHOUSE_AMBIGUOUS' => 'تعذر تحديد مخزن نقطة البيع بشكل قاطع.',
        'POS_WAREHOUSE_INVALID' => 'مخزن نقطة البيع غير صالح.',
        'POS_WAREHOUSE_NOT_CONFIGURED' => 'لم يتم إعداد مخزن لنقطة البيع.',
        'REFUND_EXCEEDS_REMAINING' => 'مبلغ الاسترداد يتجاوز المبلغ المتبقي.',
        'REFUND_IDEMPOTENCY_CONFLICT' => 'تم استخدام مفتاح العملية هذا مسبقًا لعملية استرداد مختلفة.',
        'REFUND_NOT_ALLOWED' => 'الاسترداد غير مسموح به لهذا الطلب.',
        'NO_OPEN_SHIFT' => 'يجب فتح وردية قبل تنفيذ هذه العملية.',
        'ACCOUNTING_CONFIGURATION_MISSING' => 'الإعدادات المحاسبية لهذه العملية غير مكتملة.',
        'INSUFFICIENT_STOCK' => 'الكمية المتوفرة في المخزون غير كافية.',
        'PAYMENT_VALIDATION_FAILED' => 'تعذر التحقق من بيانات الدفع.',

        // CustomerDomainException
        'CUSTOMER_PERMISSION_DENIED' => 'لا تملك صلاحية الوصول إلى بيانات هذا العميل.',
        'CUSTOMER_NOT_OPERATIONALLY_ELIGIBLE' => 'هذا العميل غير مؤهل لهذه العملية حاليًا.',
        'CUSTOMER_INVALID_TRANSITION' => 'تغيير حالة العميل المطلوب غير صالح.',
        'CUSTOMER_NUMBER_CONFLICT' => 'تعذر تخصيص رقم للعميل، يرجى المحاولة مرة أخرى.',
        'CUSTOMER_WRITE_CONFLICT' => 'حدث تعارض مع عملية أخرى على بيانات العميل، يرجى المحاولة مرة أخرى.',

        // Generic PHP DomainException fallback code (see bootstrap/app.php)
        'DOMAIN_RULE_VIOLATION' => 'لا يمكن إتمام هذه العملية وفق قواعد النظام الحالية.',
    ];

    public static function forCode(string $domainCode, string $fallback = 'لا يمكن إتمام هذه العملية حاليًا.'): string
    {
        return self::MESSAGES[$domainCode] ?? $fallback;
    }
}
