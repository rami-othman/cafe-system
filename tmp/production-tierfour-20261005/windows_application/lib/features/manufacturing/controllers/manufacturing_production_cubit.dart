import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../repositories/manufacturing_repository.dart';
import 'manufacturing_production_state.dart';

/// Production screen-cluster: recipe select -> preview -> draft -> completion
/// -> result, plus history/detail/reversal. Kept separate from the Recipes,
/// Reports, and Overview cubits.
///
/// Idempotency: each user-initiated mutation (draft creation, completion,
/// reversal) gets exactly one key, minted the moment the action starts and
/// reused for every retry of that *same* action (e.g. a timeout retry). A new
/// key is only minted once the underlying request actually changes (a
/// different recipe/qty/warehouse, a different draft being completed, a
/// different reversal reason) - mirroring `PosCubit`'s
/// fingerprint-gated `_operationKey` pattern. Keys are minted here, in the
/// Cubit, never inside the repository (which would mint a fresh key per HTTP
/// attempt and defeat the whole point).
class ManufacturingProductionCubit extends Cubit<ManufacturingProductionState> {
  ManufacturingProductionCubit({
    required this.repository,
    String Function(String operation)? operationKeyGenerator,
  }) : _operationKeyGenerator = operationKeyGenerator ?? _defaultOperationKey,
       super(const ManufacturingProductionState());

  final ManufacturingRepository repository;
  final String Function(String operation) _operationKeyGenerator;

  int _requestGeneration = 0;

  String? _draftFingerprint;
  String? _draftKey;
  String? _completeFingerprint;
  String? _completeKey;
  String? _reverseFingerprint;
  String? _reverseKey;

  Future<void> loadPreview({
    required int recipeId,
    required String qty,
    int? warehouseId,
    int? branchId,
  }) async {
    final int generation = ++_requestGeneration;
    bool isCurrent() => generation == _requestGeneration;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final preview = await repository.productionPreview(
        recipeId: recipeId,
        qty: qty,
        warehouseId: warehouseId,
        branchId: branchId,
      );
      if (!isCurrent()) return;
      emit(state.copyWith(preview: preview, clearError: true));
    } catch (error) {
      if (!isCurrent()) return;
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      if (isCurrent()) emit(state.copyWith(loading: false));
    }
  }

  Future<bool> createDraft({
    required int recipeId,
    required String qty,
    required int warehouseId,
    int? branchId,
    String? date,
  }) async {
    if (state.submitting) return false;
    final String fingerprint =
        'r$recipeId|q$qty|w$warehouseId|b$branchId|d$date';
    if (_draftFingerprint != fingerprint) {
      _draftFingerprint = fingerprint;
      _draftKey = null;
    }
    final String idempotencyKey = _draftKey ??= _operationKeyGenerator(
      'production-draft',
    );

    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final draft = await repository.createProductionDraft(<String, dynamic>{
        'recipeId': recipeId,
        'qty': qty,
        'warehouseId': warehouseId,
        if (date case final String value) 'date': value,
        if (branchId case final int value) 'branchId': value,
        'idempotencyKey': idempotencyKey,
      });
      emit(state.copyWith(submitting: false, draft: draft, clearError: true));
      _draftFingerprint = null;
      _draftKey = null;
      return true;
    } catch (error) {
      emit(state.copyWith(submitting: false, error: _messageFor(error)));
      return false;
    }
  }

  Future<void> loadDraft(int id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final draft = await repository.productionDraft(id);
      emit(state.copyWith(draft: draft, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  Future<bool> completeDraft({
    required int draftId,
    required String actualQty,
    String? date,
    List<Map<String, dynamic>>? consumption,
    Map<String, dynamic>? waste,
    List<Map<String, dynamic>>? additionalCosts,
  }) async {
    if (state.submitting) return false;
    final String fingerprint =
        'd$draftId|q$actualQty|dt$date|${consumption ?? const <dynamic>[]}|${waste ?? const <String, dynamic>{}}|${additionalCosts ?? const <dynamic>[]}';
    if (_completeFingerprint != fingerprint) {
      _completeFingerprint = fingerprint;
      _completeKey = null;
    }
    final String idempotencyKey = _completeKey ??= _operationKeyGenerator(
      'production-complete',
    );

    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final order = await repository
          .completeProductionDraft(draftId, <String, dynamic>{
            'actualQty': actualQty,
            if (date case final String value) 'date': value,
            if (consumption case final List<Map<String, dynamic>> value)
              'consumption': value,
            if (waste case final Map<String, dynamic> value) 'waste': value,
            if (additionalCosts case final List<Map<String, dynamic>> value)
              'additionalCosts': value,
            'idempotencyKey': idempotencyKey,
          });
      emit(
        state.copyWith(
          submitting: false,
          result: order,
          selected: order,
          clearError: true,
        ),
      );
      _completeFingerprint = null;
      _completeKey = null;
      return true;
    } catch (error) {
      emit(state.copyWith(submitting: false, error: _messageFor(error)));
      return false;
    }
  }

  Future<void> loadOrders({
    String? search,
    int? warehouseId,
    int? branchId,
    String? status,
    String? type,
  }) async {
    final int generation = ++_requestGeneration;
    bool isCurrent() => generation == _requestGeneration;

    emit(state.copyWith(loading: true, clearError: true));
    try {
      final orders = await repository.productionList(
        search: search,
        warehouseId: warehouseId,
        branchId: branchId,
        status: status,
        type: type,
      );
      if (!isCurrent()) return;
      emit(state.copyWith(orders: orders, clearError: true));
    } catch (error) {
      if (!isCurrent()) return;
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      if (isCurrent()) emit(state.copyWith(loading: false));
    }
  }

  Future<void> loadOrder(String idOrReference) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final order = await repository.production(idOrReference);
      emit(state.copyWith(selected: order, clearError: true));
    } catch (error) {
      emit(state.copyWith(error: _messageFor(error)));
    } finally {
      emit(state.copyWith(loading: false));
    }
  }

  /// Reverses a completed production order. The backend is fully
  /// authoritative on reversibility (`PRODUCTION_NOT_REVERSIBLE`, already
  /// returned as an Arabic message via `DomainErrorMessages` on the server) -
  /// this method never mutates `state.selected` before the backend confirms,
  /// so a failed reversal leaves the previously loaded order untouched.
  Future<bool> reverseOrder({
    required String idOrReference,
    required String reason,
  }) async {
    final String fingerprint = '$idOrReference|$reason';
    if (_reverseFingerprint != fingerprint) {
      _reverseFingerprint = fingerprint;
      _reverseKey = null;
    }
    final String idempotencyKey = _reverseKey ??= _operationKeyGenerator(
      'production-reverse',
    );

    emit(state.copyWith(submitting: true, clearError: true));
    try {
      final order = await repository.reverseProduction(
        idOrReference,
        reason,
        idempotencyKey,
      );
      emit(
        state.copyWith(submitting: false, selected: order, clearError: true),
      );
      _reverseFingerprint = null;
      _reverseKey = null;
      return true;
    } catch (error) {
      emit(state.copyWith(submitting: false, error: _messageFor(error)));
      return false;
    }
  }

  String _messageFor(Object error) {
    final ApiException? apiError = error is ApiException ? error : null;
    return apiError?.message ?? 'تعذر إتمام العملية، حاول مرة أخرى.';
  }

  static String _defaultOperationKey(String operation) {
    final int random = Random.secure().nextInt(0x100000000);
    return '$operation-${DateTime.now().microsecondsSinceEpoch}-${random.toRadixString(16)}';
  }
}
