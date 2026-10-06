import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/network/api_exception.dart';
import 'package:windows_application/features/discounts/controllers/discount_targets_cubit.dart';
import 'package:windows_application/features/discounts/models/discount_form_references.dart';
import 'package:windows_application/features/discounts/models/discount_product_selection.dart';
import 'package:windows_application/features/discounts/repositories/discounts_repository.dart';
import 'package:windows_application/features/discounts/widgets/discount_product_targets.dart';
import 'package:windows_application/l10n/app_localizations.dart';

const _product = DiscountFormReference(
  id: 1,
  name: 'Coffee',
  nameAr: 'قهوة',
  isActive: true,
);
const _saved = DiscountFormReference(id: 101, name: 'Large', isActive: true);
const _gone = DiscountFormReference(
  id: 102,
  name: 'Old size',
  isActive: true,
  archivedAt: '2026-10-01',
);

/// Serves three pages for every query except those listed in [failing].
class _Repository extends DiscountsRepository {
  final calls = <(int, String, int)>[];
  final failing = <String>{};
  final gate = <Completer<void>>[];
  bool gated = false;

  Future<DiscountReferencePage> _serve(int id, String search, int page) async {
    calls.add((id, search, page));
    if (gated) {
      final c = Completer<void>();
      gate.add(c);
      await c.future;
    }
    if (failing.contains(search)) {
      throw const ApiException(message: 'RAW SECRET', statusCode: 503);
    }
    return DiscountReferencePage(
      items: [
        DiscountFormReference(
          id: 1000 + page,
          name: 'Item $search p$page',
          isActive: true,
        ),
      ],
      currentPage: page,
      lastPage: 3,
      total: 60,
    );
  }

  @override
  Future<DiscountReferencePage> getProducts({
    String search = '',
    int page = 1,
  }) => _serve(0, search, page);
  @override
  Future<DiscountReferencePage> getVariants(
    int productId, {
    String search = '',
    int page = 1,
  }) => _serve(productId, search, page);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

IconButton _button(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip),
    );

Future<void> _open(
  WidgetTester tester,
  DiscountTargetsCubit cubit,
  int parent,
  String locale,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiscountProductTargets(
            controller: cubit,
            enabled: true,
            onChanged: () {},
          ),
        ),
      ),
    ),
  );
  await tester.tap(
    find.byKey(
      parent == 0
          ? const Key('discount-products-selector')
          : Key('discount-variants-selector-$parent'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'failed new query clears obsolete metadata; same-query failure keeps it',
    () async {
      final repo = _Repository();
      final cubit = DiscountTargetsCubit(repo);
      addTearDown(cubit.close);
      await cubit.load(search: 'old', page: 2);
      expect(cubit.state.pages[0]!.page.lastPage, 3);
      repo.failing.add('new');
      await cubit.load(search: 'new');
      final failed = cubit.state.pages[0]!;
      expect(failed.error, 'failed');
      expect(failed.page.items, isEmpty);
      expect(failed.page.currentPage, 1);
      expect(failed.page.lastPage, 1);
      expect(failed.requestedPage, 1);
      repo.failing.clear();
      await cubit.load(search: 'new', page: 2);
      repo.failing.add('new');
      await cubit.load(page: 3);
      expect(cubit.state.pages[0]!.page.currentPage, 2);
      expect(cubit.state.pages[0]!.requestedPage, 3);
      expect(cubit.state.pages[0]!.error, 'failed');
    },
  );

  for (final parent in [0, 1]) {
    final kind = parent == 0 ? 'product' : 'variant';
    for (final locale in ['en', 'ar']) {
      testWidgets(
        '$kind picker $locale: failed new search disables stale navigation and retry recovers',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _Repository();
          final cubit = DiscountTargetsCubit(repo);
          addTearDown(cubit.close);
          cubit.hydrate([
            const DiscountProductSelection(
              productId: 1,
              product: _product,
              variantMode: 'selected',
              variantIds: [101, 102],
              variants: [_saved, _gone],
            ),
          ]);
          await _open(tester, cubit, parent, locale);
          final l10n = AppLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          );
          final next = l10n.discountReferenceNext;
          final previous = l10n.discountReferencePrevious;
          expect(repo.calls.last, (parent, '', 1));
          await tester.tap(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == next),
          );
          await tester.pumpAndSettle();
          expect(cubit.state.pages[parent]!.page.currentPage, 2);

          repo.failing.add('new');
          await tester.enterText(
            find.byKey(const Key('discount-reference-search')),
            'new',
          );
          await tester.pumpAndSettle();
          expect(repo.calls.last, (parent, 'new', 1));
          expect(cubit.state.pages[parent]!.error, 'failed');
          expect(find.text(l10n.discountReferenceFailed), findsOneWidget);
          expect(find.text('2 / 3'), findsNothing);
          expect(find.text('1 / 1'), findsNothing);
          expect(_button(tester, next).onPressed, isNull);
          expect(_button(tester, previous).onPressed, isNull);
          expect(find.text('RAW SECRET'), findsNothing);
          final callsBefore = repo.calls.length;

          // A forced tap on a disabled control must not issue any request.
          await tester.tap(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == next),
            warnIfMissed: false,
          );
          await tester.pump();
          expect(repo.calls.length, callsBefore);

          // Saved selections and unavailable metadata survive the failure.
          expect(cubit.state.selections[1]!.variantIds, [101, 102]);
          if (parent != 0) {
            expect(find.text(l10n.discountUnavailableTarget), findsWidgets);
          }

          repo.failing.clear();
          await tester.tap(find.text(l10n.commonRetry));
          await tester.pumpAndSettle();
          expect(repo.calls.last, (parent, 'new', 1));
          expect(cubit.state.pages[parent]!.error, isNull);
          expect(find.text('1 / 3'), findsOneWidget);
          expect(_button(tester, previous).onPressed, isNull);
          expect(_button(tester, next).onPressed, isNotNull);

          await tester.tap(
            find.byWidgetPredicate((w) => w is IconButton && w.tooltip == next),
          );
          await tester.pumpAndSettle();
          expect(repo.calls.last, (parent, 'new', 2));
          expect(find.text('2 / 3'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l10n.commonCancel).last);
          await tester.pumpAndSettle();
        },
      );
    }

    testWidgets(
      '$kind picker: failed page navigation retries same query and page; navigation locked while loading/error',
      (tester) async {
        final repo = _Repository();
        final cubit = DiscountTargetsCubit(repo);
        addTearDown(cubit.close);
        cubit.hydrate([
          const DiscountProductSelection(
            productId: 1,
            product: _product,
            variantMode: 'selected',
            variantIds: [101],
            variants: [_saved],
          ),
        ]);
        await _open(tester, cubit, parent, 'en');
        final next = 'Next page';
        final previous = 'Previous page';
        await tester.enterText(
          find.byKey(const Key('discount-reference-search')),
          'tea',
        );
        await tester.pumpAndSettle();
        expect(repo.calls.last, (parent, 'tea', 1));

        repo.failing.add('tea');
        await tester.tap(
          find.byWidgetPredicate((w) => w is IconButton && w.tooltip == next),
        );
        await tester.pumpAndSettle();
        expect(repo.calls.last, (parent, 'tea', 2));
        final failed = cubit.state.pages[parent]!;
        expect(failed.error, 'failed');
        expect(failed.requestedPage, 2);
        expect(_button(tester, next).onPressed, isNull);
        expect(_button(tester, previous).onPressed, isNull);

        repo
          ..failing.clear()
          ..gated = true;
        await tester.tap(find.text('Retry'));
        await tester.pump();
        expect(repo.calls.last, (parent, 'tea', 2));
        expect(cubit.state.pages[parent]!.loading, isTrue);
        expect(_button(tester, next).onPressed, isNull);
        expect(_button(tester, previous).onPressed, isNull);
        repo.gate.last.complete();
        await tester.pumpAndSettle();
        expect(cubit.state.pages[parent]!.page.currentPage, 2);
        expect(_button(tester, next).onPressed, isNotNull);
        expect(_button(tester, previous).onPressed, isNotNull);
        expect(cubit.state.selections[1]!.variantIds, [101]);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
      },
    );
  }
}
