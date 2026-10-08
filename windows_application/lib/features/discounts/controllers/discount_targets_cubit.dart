import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_exception.dart';
import '../models/discount_product_selection.dart';
import '../models/discount_form_references.dart';
import '../repositories/discounts_repository.dart';

class DiscountTargetPageState {
  const DiscountTargetPageState({
    this.page = const DiscountReferencePage(),
    this.pageQuery = '',
    this.search = '',
    this.requestedPage = 1,
    this.loading = false,
    this.error,
  });
  // Last successful page; its metadata belongs to [pageQuery] only.
  final DiscountReferencePage page;
  final String pageQuery;
  final String search;
  final int requestedPage;
  final bool loading;
  final String? error;
}

class DiscountTargetsState extends Equatable {
  const DiscountTargetsState({
    this.selections = const {},
    this.pages = const {},
  });
  final Map<int, DiscountProductSelection> selections;
  // Zero identifies the product page; positive keys identify variant parents.
  final Map<int, DiscountTargetPageState> pages;
  bool get isValid =>
      selections.values.every((s) => s.isValid && !s.hasUnavailable);
  @override
  List<Object?> get props => [selections, pages];
}

class DiscountTargetsCubit extends Cubit<DiscountTargetsState> {
  DiscountTargetsCubit(this.repository) : super(const DiscountTargetsState());
  final DiscountsRepository repository;
  final Map<int, int> _requests = {};
  int _epoch = 0;
  final Map<int, Map<int, DiscountFormReference>> _known = {};
  void hydrate(List<DiscountProductSelection> selections) {
    _epoch++;
    _known.clear();
    emit(
      DiscountTargetsState(
        selections: Map.unmodifiable({
          for (final s in selections) s.productId: s,
        }),
      ),
    );
  }

  void clear() => hydrate([]);

  /// A reference already returned by a page load (e.g. a variant picked for a
  /// package requirement), used to label it after the picker closes.
  DiscountFormReference? reference(int parentId, int id) =>
      _known[parentId]?[id];
  void invalidatePage(int key) {
    _requests[key] = (_requests[key] ?? 0) + 1;
  }

  void removeProduct(int id) {
    invalidatePage(id);
    final selections = {...state.selections}..remove(id);
    final pages = {...state.pages}..remove(id);
    emit(
      DiscountTargetsState(
        selections: Map.unmodifiable(selections),
        pages: Map.unmodifiable(pages),
      ),
    );
  }

  void setProducts(Set<int> ids) {
    for (final id in state.selections.keys.toList()) {
      if (!ids.contains(id)) removeProduct(id);
    }
    final selections = {...state.selections};
    for (final id in ids) {
      selections.putIfAbsent(
        id,
        () => DiscountProductSelection(productId: id, product: _known[0]?[id]),
      );
    }
    emit(
      DiscountTargetsState(
        selections: Map.unmodifiable(selections),
        pages: state.pages,
      ),
    );
  }

  void setMode(int id, String mode) {
    final old = state.selections[id];
    if (old == null) return;
    invalidatePage(id);
    _put(
      DiscountProductSelection(
        productId: id,
        product: old.product,
        variantMode: mode,
        variantIds: mode == 'all' ? const [] : old.variantIds,
        variants: old.variants,
      ),
    );
  }

  void setVariants(int id, Set<int> ids) {
    final old = state.selections[id];
    if (old == null || old.variantMode != 'selected') return;
    final metadata = {for (final v in old.variants) v.id: v, ...?_known[id]};
    _put(
      DiscountProductSelection(
        productId: id,
        product: old.product,
        variantMode: 'selected',
        variantIds: List.unmodifiable(ids),
        variants: List.unmodifiable(
          ids.map((id) => metadata[id]).whereType<DiscountFormReference>(),
        ),
      ),
    );
  }

  void _put(DiscountProductSelection selection) => emit(
    DiscountTargetsState(
      selections: Map.unmodifiable({
        ...state.selections,
        selection.productId: selection,
      }),
      pages: state.pages,
    ),
  );
  Future<void> load({int productId = 0, String? search, int? page}) async {
    final previous = state.pages[productId] ?? const DiscountTargetPageState();
    final query = (search ?? previous.search).trim();
    final requestedPage = page ?? (search != null ? 1 : previous.requestedPage);
    final sameQuery = previous.pageQuery == query;
    final retained = sameQuery ? previous.page : const DiscountReferencePage();
    final token = (_requests[productId] ?? 0) + 1;
    _requests[productId] = token;
    final epoch = _epoch;
    void put(DiscountTargetPageState value) => emit(
      DiscountTargetsState(
        selections: state.selections,
        pages: Map.unmodifiable({...state.pages, productId: value}),
      ),
    );
    put(
      DiscountTargetPageState(
        page: retained,
        pageQuery: query,
        search: query,
        requestedPage: requestedPage,
        loading: true,
      ),
    );
    bool current() =>
        !isClosed && epoch == _epoch && _requests[productId] == token;
    try {
      final result = productId == 0
          ? await repository.getProducts(search: query, page: requestedPage)
          : await repository.getVariants(
              productId,
              search: query,
              page: requestedPage,
            );
      if (!current()) return;
      _known[productId] = {
        ...?_known[productId],
        for (final item in result.items) item.id: item,
      };
      put(
        DiscountTargetPageState(
          page: result,
          pageQuery: query,
          search: query,
          requestedPage: requestedPage,
        ),
      );
    } catch (error) {
      if (!current()) return;
      put(
        DiscountTargetPageState(
          page: retained,
          pageQuery: query,
          search: query,
          requestedPage: requestedPage,
          error: error is ApiException && error.statusCode == 403
              ? 'forbidden'
              : 'failed',
        ),
      );
    }
  }
}
