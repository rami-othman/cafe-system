Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputDir = Join-Path $PSScriptRoot 'arabic_rendered'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$pageWidth = 1654
$pageHeight = 2339
$margin = 132
$ink = [System.Drawing.ColorTranslator]::FromHtml('#231005')
$muted = [System.Drawing.ColorTranslator]::FromHtml('#6B5A50')
$primary = [System.Drawing.ColorTranslator]::FromHtml('#3B2417')
$accent = [System.Drawing.ColorTranslator]::FromHtml('#C47A3A')
$sand = [System.Drawing.ColorTranslator]::FromHtml('#FAF7F2')
$line = [System.Drawing.ColorTranslator]::FromHtml('#E7E2DA')
$white = [System.Drawing.Color]::White
$good = [System.Drawing.ColorTranslator]::FromHtml('#256A48')
$warn = [System.Drawing.ColorTranslator]::FromHtml('#A85D13')

$fontTitle = [System.Drawing.Font]::new('Arial', 42, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fontH1 = [System.Drawing.Font]::new('Arial', 28, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fontH2 = [System.Drawing.Font]::new('Arial', 21, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fontBody = [System.Drawing.Font]::new('Arial', 16, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fontSmall = [System.Drawing.Font]::new('Arial', 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fontTable = [System.Drawing.Font]::new('Arial', 12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fontTableHead = [System.Drawing.Font]::new('Arial', 12, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fontLabel = [System.Drawing.Font]::new('Arial', 12, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

function New-Format([System.Drawing.StringAlignment]$alignment = [System.Drawing.StringAlignment]::Far) {
  $fmt = [System.Drawing.StringFormat]::new()
  $null = $fmt.Alignment = $alignment
  $null = $fmt.LineAlignment = [System.Drawing.StringAlignment]::Near
  $null = $fmt.FormatFlags = [System.Drawing.StringFormatFlags]::DirectionRightToLeft
  $null = $fmt.Trimming = [System.Drawing.StringTrimming]::Word
  return $fmt
}

function New-Page($pageNumber, $label) {
  $script:bmp = [System.Drawing.Bitmap]::new($pageWidth, $pageHeight, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $script:g = [System.Drawing.Graphics]::FromImage($bmp)
  $null = $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $null = $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $g.Clear($sand)
  $g.FillRectangle(([System.Drawing.SolidBrush]::new($primary)), 0, 0, $pageWidth, 154)
  $g.DrawString('كافيه 6:18 | عمليات المنصة', $fontSmall, ([System.Drawing.SolidBrush]::new($white)), ([System.Drawing.RectangleF]::new($margin, 58, 700, 35)), (New-Format))
  $g.DrawString($label, $fontSmall, ([System.Drawing.SolidBrush]::new($white)), ([System.Drawing.RectangleF]::new($pageWidth-$margin-350, 58, 350, 35)), (New-Format))
  $g.DrawLine(([System.Drawing.Pen]::new($line, 1)), $margin, $pageHeight-60, $pageWidth-$margin, $pageHeight-60)
  $g.DrawString('خطة لوحة تحكم مدير المنصة - Cafe 6:18', $fontSmall, ([System.Drawing.SolidBrush]::new($muted)), ([System.Drawing.RectangleF]::new($margin, $pageHeight-46, 700, 25)), (New-Format))
  $g.DrawString("الصفحة $pageNumber", $fontSmall, ([System.Drawing.SolidBrush]::new($muted)), ([System.Drawing.RectangleF]::new($pageWidth-$margin-160, $pageHeight-46, 160, 25)), (New-Format))
  $script:cursorY = 218
}

function Add-Text($value, $font, $color, $height, $after = 12) {
  $rect = [System.Drawing.RectangleF]::new($margin, $cursorY, $pageWidth-2*$margin, $height)
  $g.DrawString($value, $font, ([System.Drawing.SolidBrush]::new($color)), $rect, (New-Format))
  $script:cursorY += [Math]::Ceiling(($g.MeasureString($value, $font, $pageWidth-2*$margin, (New-Format))).Height) + $after
}

function Add-Heading($value) { Add-Text $value $fontH1 $primary 100 14 }
function Add-Subheading($value) { Add-Text $value $fontH2 $primary 70 8 }
function Add-Paragraph($value) { Add-Text $value $fontBody $ink 300 13 }
function Add-Bullets($items) { foreach($item in $items) { Add-Text "- $item" $fontBody $ink 90 4 }; $script:cursorY += 7 }

function Add-Callout($label, $value, $barColor = $accent) {
  $textWidth = $pageWidth-2*$margin-56
  $textHeight = [Math]::Ceiling(($g.MeasureString($value, $fontBody, $textWidth, (New-Format))).Height)
  $boxHeight = 54 + $textHeight
  $g.FillRectangle(([System.Drawing.SolidBrush]::new($white)), $margin, $cursorY, $pageWidth-2*$margin, $boxHeight)
  $g.DrawRectangle(([System.Drawing.Pen]::new($line, 1)), $margin, $cursorY, $pageWidth-2*$margin, $boxHeight)
  $g.FillRectangle(([System.Drawing.SolidBrush]::new($barColor)), $pageWidth-$margin-5, $cursorY, 5, $boxHeight)
  $g.DrawString($label, $fontLabel, ([System.Drawing.SolidBrush]::new($barColor)), ([System.Drawing.RectangleF]::new($margin+20, $cursorY+13, $textWidth, 25)), (New-Format))
  $g.DrawString($value, $fontBody, ([System.Drawing.SolidBrush]::new($ink)), ([System.Drawing.RectangleF]::new($margin+20, $cursorY+39, $textWidth, $textHeight+8)), (New-Format))
  $script:cursorY += $boxHeight + 18
}

function Add-Table($headers, $rows, $widths) {
  $xRight = $pageWidth-$margin
  $headerHeight = 40
  $x = $xRight
  for($i=0; $i -lt $headers.Count; $i++) {
    $x -= $widths[$i]
    $g.FillRectangle(([System.Drawing.SolidBrush]::new($primary)), $x, $cursorY, $widths[$i], $headerHeight)
    $g.DrawString($headers[$i], $fontTableHead, ([System.Drawing.SolidBrush]::new($white)), ([System.Drawing.RectangleF]::new($x+7, $cursorY+10, $widths[$i]-14, 26)), (New-Format))
  }
  $script:cursorY += $headerHeight
  foreach($row in $rows) {
    $maxHeight = 36
    for($i=0; $i -lt $row.Count; $i++) {
      $h = [Math]::Ceiling(($g.MeasureString($row[$i], $fontTable, $widths[$i]-14, (New-Format))).Height) + 18
      if($h -gt $maxHeight) { $maxHeight = $h }
    }
    $x = $xRight
    for($i=0; $i -lt $row.Count; $i++) {
      $x -= $widths[$i]
      $g.FillRectangle(([System.Drawing.SolidBrush]::new($white)), $x, $cursorY, $widths[$i], $maxHeight)
      $g.DrawRectangle(([System.Drawing.Pen]::new($line, 1)), $x, $cursorY, $widths[$i], $maxHeight)
      $g.DrawString($row[$i], $fontTable, ([System.Drawing.SolidBrush]::new($ink)), ([System.Drawing.RectangleF]::new($x+7, $cursorY+9, $widths[$i]-14, $maxHeight-12)), (New-Format))
    }
    $script:cursorY += $maxHeight
  }
  $script:cursorY += 16
}

function Save-Page($number) {
  $path = Join-Path $outputDir "page-$number.jpg"
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
  $g.Dispose(); $bmp.Dispose()
}

New-Page 1 'خطة لوحة التحكم'
$cursorY = 465
Add-Text 'خطة لوحة تحكم مدير المنصة' $fontTitle $primary 160 12
Add-Text 'مخطط المنتج والعمليات والتنفيذ لمنصة Cafe 6:18 متعددة المستأجرين.' $fontH2 $muted 70 24
Add-Callout 'الغرض' 'تحديد أول لوحة تحكم جاهزة للإنتاج لمشغلي المنصة. يجب أن تجيب بوضوح: هل المنصة بحالة جيدة؟ هل ينمو المستأجرون ويلتزمون؟ ما الذي يحتاج إلى إجراء الآن؟'
Add-Subheading 'نطاق المستند'
Add-Paragraph 'تغطي هذه الخطة لوحة الويب الخاصة بمدير المنصة، وليست نظام نقاط البيع أو لوحة الإدارة الداخلية لكل مقهى. وهي موجهة لفريق تشغيل منصة Cafe 6:18 متعددة المستأجرين.'
Add-Table @('وتيرة الاستخدام','النتيجة الأساسية','الفئة') @(
  @('يومياً','اكتشاف مشاكل المستأجرين والإيراد والمنصة بشكل عاجل.','مشغل المنصة'),
  @('أسبوعياً','متابعة التبني والصحة التجارية والاتجاهات التشغيلية.','مدير المنصة'),
  @('عند الطلب','تحديد المستأجرين الذين يحتاجون متابعة أو تسوية.','الدعم والمالية')
) @(180,500,310)
Add-Subheading 'ترتيب التسليم المقترح'
Add-Paragraph 'ابدأ بجعل لوحة التحكم موثوقة وقابلة لاتخاذ الإجراء، ثم أضف التحليلات التفصيلية. لا تبن مخططات تجميلية قبل تثبيت الصلاحيات وحداثة البيانات والتنبيهات التشغيلية.'
Add-Text 'الإصدار 1.0 | 20 تموز 2026 | اللغة: العربية' $fontSmall $muted 35 0
Save-Page 1

New-Page 2 'الأهداف والبنية'
Add-Heading '1. أهداف المنتج والمبادئ'
Add-Bullets @(
  'تقديم ملخص صحي للمنصة خلال خمس ثوانٍ.',
  'تحويل التغييرات المهمة إلى إجراءات واضحة ومقيدة بالصلاحيات.',
  'ربط كل بطاقة بقائمة مستأجرين أو تقرير أو صفحة تفاصيل مفلترة.',
  'إظهار حداثة البيانات وسياق الحساب، وعدم عرض إجماليات غير مفسرة.',
  'الإصدار الأول مكتبي أولاً، متجاوب حتى عرض الجهاز اللوحي، ومهيأ لاتجاه RTL.'
)
Add-Callout 'خارج نطاق الإصدار الأول' 'لا نكرر شاشات التشغيل الخاصة بالـPOS، ولا نبني مستودع ذكاء أعمال كامل، ولا نستبدل صفحات المستأجرين والفوترة وسجل التدقيق وصحة النظام. وظيفة اللوحة هي التلخيص والانتقال إلى هذه الوحدات.' $warn
Add-Heading '2. هيكل المعلومات'
Add-Paragraph 'تستخدم اللوحة نطاقاً زمنياً عاماً واحداً وفترة مقارنة واحدة. يجب أن يبقى شريط الفلاتر المختصر ظاهراً أعلى منطقة المحتوى.'
Add-Table @('لماذا؟','المحتوى','المنطقة') @(
  @('يوضح سياق التقارير والثقة بالبيانات.','نطاق التاريخ، المنطقة الزمنية، وضع العملة، حالة التحديث، قائمة المشغل.','الرأس العام'),
  @('يعرض المشاكل قبل المؤشرات.','تنبيهات حرجة وإجراءات مقترحة.','شريط الانتباه'),
  @('نبض عمل سريع.','المستأجرون، الاشتراكات، المبيعات، الطلبات، صحة الدفع.','صف KPIs'),
  @('يكشف الاتجاهات والشذوذ.','اتجاه المبيعات والطلبات، نمو المستأجرين، توزيع الاشتراكات.','الاتجاهات'),
  @('يجعل الصفحة قابلة للتنفيذ.','تجارب قريبة الانتهاء، مستأجرون موقوفون، وظائف فاشلة، متابعات دعم.','قوائم التشغيل'),
  @('يوفر المساءلة والسياق.','أحداث المستأجرين والأمن والتغييرات الكبرى.','النشاط الأخير')
) @(300,500,190)
Save-Page 2

New-Page 3 'التخطيط والمؤشرات'
Add-Heading '3. تخطيط لوحة التحكم المقترح للإصدار الأول'
Add-Paragraph 'استخدم شبكة من اثني عشر عموداً على سطح المكتب. عند العروض المتوسطة تكدس المخططات والقوائم، مع إبقاء شريط الإجراءات وصف المؤشرات. هذا مخطط محتوى وليس نموذج تصميم بصري.'
Add-Table @('التفاعل','الوحدات','الصف') @(
  @('تغيير الفلاتر يعيد تحميل جميع الوحدات.','شريط السياق: التاريخ، المقارنة، وقت آخر تحديث.','1'),
  @('كل تنبيه يفتح التفاصيل أو القائمة المفلترة ذات الصلة.','شريط الانتباه: من 0 إلى 5 تنبيهات ذات أولوية.','2'),
  @('كل بطاقة تنتقل إلى صفحة تفاصيل بنفس الفلاتر.','ست بطاقات مؤشرات رئيسية.','3'),
  @('تلميحات عند المرور وجدول بيانات بديل للوصول.','اتجاه المبيعات والطلبات (8 أعمدة) | مزيج الاشتراكات (4 أعمدة).','4'),
  @('النقر على جزء حالة يطبق الفلتر المناسب.','نمو المستأجرين (6) | ملخص صحة المنصة (6).','5'),
  @('روابط عميقة وإقرار عند امتلاك الصلاحية.','قائمة إجراءات (7) | نشاط حديث (5).','6')
) @(340,500,150)
Add-Heading '4. بطاقات المؤشرات المطلوبة'
Add-Paragraph 'كل بطاقة تعرض القيمة الحالية، والفرق عن فترة المقارنة، وتعريفاً توضيحياً، ووقت حداثة البيانات. تُجمع المبالغ حسب العملة ما لم تعتمد المنصة سياسة تحويل رسمية.'
Add-Table @('الأولوية','صفحة التفاصيل','التعريف','المؤشر') @(
  @('P0','المستأجرون بحالة نشط.','المستأجرون النشطون في نهاية الفترة المحددة.','المستأجرون النشطون'),
  @('P0','الدليل حسب تاريخ الإنشاء.','المستأجرون الذين تم إنشاؤهم خلال الفترة.','مستأجرون جدد'),
  @('P0','الاشتراكات حسب تاريخ الانتهاء.','التجارب المنتهية خلال 7 أو 14 يوماً.','تجارب تنتهي قريباً'),
  @('P0','المستأجرون بحالة موقوف.','المستأجرون الموقوفون حالياً.','مستأجرون موقوفون'),
  @('P1','التحليلات بنفس النطاق الزمني.','إجمالي مبيعات الطلبات لكل عملة أصلية.','إجمالي المبيعات'),
  @('P1','تقرير التحليلات والطلبات.','الطلبات المدفوعة أو المكتملة حسب عقد الحالة.','الطلبات المكتملة'),
  @('P0','الاشتراكات حسب الحالة.','عدد النشطة والتجريبية والمتأخرة والملغاة.','صحة الاشتراكات'),
  @('P0','صحة النظام.','الخدمات الحرجة ووظائف الخلفية الفاشلة.','صحة المنصة')
) @(90,310,400,190)
Save-Page 3

New-Page 4 'العمليات والـAPI'
Add-Heading '5. المخططات وقوائم التشغيل والنشاط'
Add-Table @('القواعد','الحد الأدنى للمحتوى','الوحدة') @(
  @('افصل العملات أو وضح سياسة تحويل معتمدة.','إجمالي مبيعات يومية وطلبات مكتملة؛ 7 و30 و90 يوماً.','اتجاه المبيعات والطلبات'),
  @('أعمدة أو خطوط مجمعة مع فترة مقارنة.','مستأجرون منشأون ومفعّلون وموقوفون عبر الزمن.','نمو المستأجرين'),
  @('النقر على جزء يفتح قائمة اشتراكات مفلترة.','أعداد حسب الخطة والحالة.','مزيج الاشتراكات'),
  @('رتب حسب الاستعجال؛ أظهر المالك والموعد والإجراء.','تجارب تنتهي، متأخرات، إيقافات، فشل إعداد، حوادث صحة.','قائمة الإجراءات'),
  @('أظهر الفاعل والوقت والهدف ورابط سجل التدقيق.','إنشاء مستأجر، تغيير حالة أو خطة، حدث أمان للمشرف.','النشاط الأخير'),
  @('أظهر الحالة والحد ووقت الفحص وسجل الحوادث.','إتاحة الـAPI، فشل الطوابير، المهام المجدولة، معدل الأخطاء.','صحة المنصة')
) @(350,480,160)
Add-Callout 'قاعدة قابلية التنفيذ' 'لا ترفع أي عنصر إلى الصفحة الرئيسية ما لم يمكن التحقيق فيه أو اتخاذ إجراء حياله. كل تحذير يحتاج مالكاً وحداً واضحاً ووجهة انتقال.' $good
Add-Heading '6. الحالات والصلاحيات والثقة'
Add-Table @('السلوك المطلوب','الموضوع') @(
  @('يستدعي حارس المسار /auth/me قبل عرض المحتوى المحمي. المستخدم غير المسجل ينتقل إلى /login.','المصادقة'),
  @('تُخفى الإجراءات بلا صلاحية، مع فرض الصلاحية نفسها في Laravel API وإظهار 403 واضح عند رفض الرابط المباشر.','التفويض'),
  @('استخدم هياكل تحميل للمؤشرات والمخططات. اعرض إعادة المحاولة للوحدة الفاشلة ولا تحول الخطأ إلى قيمة صفرية.','التحميل والأخطاء'),
  @('اعرض وقت آخر تحديث وزر تحديث واضحاً، وحذر من البيانات القديمة بعد حد متفق عليه.','حداثة البيانات'),
  @('تنقل بلوحة المفاتيح، تركيز مرئي، جداول دلالية، بدائل نصية للمخططات، ومفاتيح ترجمة وتخطيط RTL آمن.','الوصول وRTL')
) @(700,290)
Save-Page 4

New-Page 5 'خارطة التنفيذ'
Add-Heading '7. متطلبات الـAPI والبيانات'
Add-Paragraph 'يوفر الـBackend الحالي تسجيل الدخول والمستخدم الحالي ومؤشرات اللوحة والبحث عن المستأجرين وإنشاؤهم وتفاصيلهم وتغيير حالتهم. يحتاج الإصدار الأول عقد بيانات تجميعي ثابتاً وروابط انتقال تفصيلية. يفضل استخدام endpoint واحد للملخصات مع الإبقاء على أخطاء الوحدات ظاهرة في الواجهة.'
Add-Table @('الحالة','المطلوب للوحة','المصدر') @(
  @('متوفر','بدء الجلسة واسم المستخدم والصلاحيات.','GET /auth/me'),
  @('متوفر ويحتاج توسيعاً','المؤشرات الأساسية والمبيعات حسب العملة والمستأجرون الجدد.','GET /dashboard'),
  @('متوفر ويحتاج ربط واجهة','قوائم التفاصيل والصفحات والفلاتر.','GET /tenants'),
  @('مطلوب','قوائم التجارب والمتأخرات ومزيج الخطط والحالات.','GET /subscriptions'),
  @('مطلوب','الاتجاهات وتجميع النمو والإيراد.','GET /analytics/overview'),
  @('مطلوب','ملخص الخدمات والطوابير والحالات.','GET /system/health'),
  @('مطلوب','نشاط المنصة الحديث.','GET /audit-logs'),
  @('متوفر ويحتاج ربط واجهة','إنهاء الجلسة بأمان.','POST /auth/logout')
) @(190,500,300)
Add-Paragraph 'معاملات الاستعلام المقترحة: from وto وcompareTo وtimezone وcurrencyMode. يجب أن تتضمن الاستجابة generatedAt وإصدار تعريفات المؤشرات وحالة كل وحدة إن أمكن.'
Add-Heading '8. خارطة طريق التسليم'
Add-Table @('معيار الخروج','المخرجات الأساسية','النتيجة','المرحلة') @(
  @('نجاح بناء الإنتاج وإعادة توجيه المسارات المحمية.','إصلاح خطأ Next.js، حارس مسار، تسجيل خروج، تنقل نشط، حالات مشتركة.','هيكل آمن قابل للبناء.','0 - الأساس'),
  @('يمكن للمشغل تحديد النشطين والتجارب والإيقافات والمبيعات وصحة المنصة.','شريط سياق وتنبيهات و6 مؤشرات وAPI موسع وحالات فارغة وخطأ وحداثة.','رؤية تشغيلية يومية.','1 - اللوحة الأساسية'),
  @('يمكن إيجاد المستأجر وفحصه وإنشاؤه وتغيير حالته دون أدوات API.','تفاصيل المستأجر وتغيير الحالة والبحث والفلاتر والصفحات والتحقق من الإعداد.','دورة حياة قابلة للتنفيذ.','2 - عمليات المستأجر'),
  @('لكل مخطط وتنبيه رابط تفصيلي موثق.','اشتراكات واتجاهات وتحليلات وصحة نظام وسجلات تدقيق وقائمة تنبيهات.','اتجاهات واستثناءات.','3 - التجارة والصحة'),
  @('نجاح فحوص القبول وجاهزية العربية.','RTL وترجمة وتدقيق وصول واختبارات وأداء وتصدير.','ثقة تشغيلية.','4 - التحصين')
) @(220,380,250,140)
Save-Page 5

New-Page 6 'القبول والقرارات'
Add-Heading '9. قائمة قبول الإصدار'
Add-Bullets @(
  'تنجح عملية البناء والفحص النوعي في مسار الإنتاج.',
  'لا يرى المستخدم غير المسجل بيانات محمية، ولا يرى المسجل إلا الإجراءات المسموح بها.',
  'لكل مؤشر تعريف وفترة زمنية ومقارنة ووقت حداثة واضح.',
  'لا تتعامل اللوحة مع فشل API على أنه بيانات بقيمة صفر.',
  'كل بطاقة وجزء مخطط وتنبيه ونشاط يقود إلى صفحة تفاصيل مفلترة صحيحة.',
  'تتبع العملة سياسة معتمدة ولا تخلط العملات بصمت.',
  'تفي تجربة سطح المكتب واللوحي ولوحة المفاتيح وقارئ الشاشة بالخط الأساسي المتفق عليه.',
  'تغطي الاختبارات حارس المصادقة وحالات التحميل والخطأ والفراغ وانتقال الفلاتر والروابط الرئيسية.'
)
Add-Heading '10. قرارات يجب تثبيتها قبل التنفيذ'
Add-Table @('الافتراضي المقترح','أهميته','القرار') @(
  @('عرض الإجماليات بالعملات الأصلية؛ إضافة التحويل فقط بمصدر أسعار موثوق.','يحدد إمكانية جمع الإجماليات.','سياسة عملة الإيراد'),
  @('توثيق حالات الطلب والدفع بدقة في عقد API.','يؤثر في مؤشرات المبيعات والطلبات.','تعريف الطلب المكتمل'),
  @('تعيين فريق أو دور ومسار تصعيد لكل نوع تنبيه.','يمنع تجاهل التحذيرات.','مالك التنبيه'),
  @('تحديث عند الطلب مع طابع وقت واضح؛ تحسين التحديث الحي لاحقاً.','يحدد توقعات المستخدم وكلفة التنفيذ.','هدف تحديث البيانات'),
  @('مدير منصة أعلى، عمليات، دعم، مالية، محلل للقراءة فقط.','يشكل الإجراءات المرئية.','الأدوار الأولية')
) @(390,350,240)
Add-Callout 'الخطوة التالية المقترحة' 'اعتمد المرحلة صفر وتعريفات مؤشرات الإصدار الأول، ثم نفذ عقد API الخاص باللوحة وهيكل الويب المحمي معاً. هذا يمنع بناء واجهة جميلة فوق بيانات غير مستقرة أو مسارات غير آمنة.'
Save-Page 6

Write-Output "Arabic pages written to $outputDir"
