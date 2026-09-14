import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/branding/app_brand.dart';
import 'package:windows_application/core/branding/brand_header.dart';

void main() {
  testWidgets('long Arabic branch identity renders without overflow', (
    WidgetTester tester,
  ) async {
    const BrandIdentity identity = BrandIdentity(
      displayName: 'فرع المطار الدولي للصالة الرئيسية طويل الاسم',
      subtitle: 'نقطة البيع',
      windowTitle: 'فرع المطار - Cafe 618',
      isCashier: true,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(width: 190, child: BrandHeader(identity: identity)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
  });

  testWidgets('header updates immediately when the active identity changes', (
    WidgetTester tester,
  ) async {
    const BrandIdentity first = BrandIdentity(
      displayName: 'المزة',
      subtitle: 'نقطة البيع',
      windowTitle: 'المزة - Cafe 618',
      isCashier: true,
    );
    const BrandIdentity second = BrandIdentity(
      displayName: 'فرع المطار',
      subtitle: 'نقطة البيع',
      windowTitle: 'فرع المطار - Cafe 618',
      isCashier: true,
    );

    await tester.pumpWidget(
      const MaterialApp(home: BrandHeader(identity: first)),
    );
    expect(find.text('المزة'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: BrandHeader(identity: second)),
    );
    expect(find.text('المزة'), findsNothing);
    expect(find.text('فرع المطار'), findsOneWidget);
  });
}
