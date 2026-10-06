# مقترح D2-19 للمراجعة — غير مطبق

بوابات قبول Windows والطباعة ومصفوفة السياقات لم تُغلق، لذا D2-19 مفتوحة ولا يوجد تفويض تشغيل. لم تُضف migration قابلة للاكتشاف إلى database/migrations، ولم تُعدّل migration مطبقة.

بعد إغلاق القبول ومراجعة مستقلة، يكون التغيير additive جديدًا يستبدل `discount_settings_values_check`، ويحذف شرط `NOT automatic_enabled` وحده، ويحفظ باقي شروط version/enums/cap/after_items:

```sql
ALTER TABLE tenant_discount_settings DROP CONSTRAINT discount_settings_values_check;
ALTER TABLE tenant_discount_settings ADD CONSTRAINT discount_settings_values_check CHECK (
  version > 0
  AND selection_strategy IN ('highest_saving','lowest_saving','priority')
  AND combination_mode IN ('single','disjoint_items')
  AND order_discount_behavior IN ('exclusive','after_items')
  AND coupon_behavior IN ('exclusive','follow_combination_rules')
  AND manual_behavior IN ('exclusive','follow_combination_rules')
  AND (maximum_total_discount_percent IS NULL OR (maximum_total_discount_percent > 0 AND maximum_total_discount_percent <= 100))
  AND (order_discount_behavior <> 'after_items' OR combination_mode = 'disjoint_items')
);
```

يُنفذ الاستبدال داخل transaction وبمهلة lock محددة؛ لا UPDATE ولا backfill ولا تغيير إعداد مقهى. يظل automaticEnabled=false حتى اختيار المقهى عبر expectedVersion والحقول الثمانية. إزالة CHECK وحدها لا تفتح runtime: DiscountSettingsService وDiscountEngineProtocol وvalidation إنشاء السياسة تحتاج مصدر capability server-side خاص بالإصدار المراجع، مع إبقاء حماية العميل القديم. لا override في Flutter ولا endpoint تجاوز عام.

المخاطر: قفل ALTER TABLE وتأخر الكتابة، اختلاف إصدارات العملاء، وفتح discovery دون حماية quote/breakdown. rollout يكون schema ثم Backend/clients المتوافقين ثم اختيار المقهى؛ snapshot المدفوع لا يُعاد حسابه. لا تُعكس migration تلقائيًا بعد وجود صفوف enabled=true: down يجب أن يرفضها صراحة، ويُفضّل roll-forward متحكم به على إطفاء بيانات المقاهي بصمت.

المتبقي: migration فعلية additive؛ اختبارها وroll-forward معزولًا؛ إثبات أن false لا يتغير وtrue يتطلب capability المراجعة؛ رفض enums/caps/combination غير الصحيحة؛ توافق العميل القديم وreplay؛ مطابقة schema التشغيل قراءةً فقط؛ مراجعة مستقلة وتفويض صريح. **SQL أعلاه لم يُطبق ولم يُختبر كتفعيل؛ ليس دليل قبول migration.**
