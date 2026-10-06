import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/api_exception.dart';
import '../models/discount_settings.dart';
import '../repositories/discount_settings_repository.dart';

enum DiscountSettingsStatus {
  loading,
  loaded,
  saving,
  failure,
  forbidden,
  conflict,
}

class DiscountSettingsState extends Equatable {
  const DiscountSettingsState({
    this.status = DiscountSettingsStatus.loading,
    this.saved,
    this.draft = const DiscountSettingsDraft(),
    this.requiresReview = false,
    this.errorCode,
  });
  final DiscountSettingsStatus status;
  final SavedDiscountSettings? saved;
  final DiscountSettingsDraft draft;
  final bool requiresReview;
  final String? errorCode;
  bool get dirty => saved != null && saved!.draft != draft;
  bool get canSave =>
      saved != null &&
      dirty &&
      draft.isValid &&
      !requiresReview &&
      status != DiscountSettingsStatus.saving &&
      status != DiscountSettingsStatus.loading &&
      status != DiscountSettingsStatus.forbidden &&
      (!draft.automaticEnabled || saved!.engineReady);
  @override
  List<Object?> get props => [status, saved, draft, requiresReview, errorCode];
}

class DiscountSettingsCubit extends Cubit<DiscountSettingsState> {
  DiscountSettingsCubit(this.repository) : super(const DiscountSettingsState());
  final DiscountSettingsRepository repository;
  int _generation = 0;
  Future<void> load({bool preserveDraft = false, bool conflict = false}) async {
    if (isClosed || state.status == DiscountSettingsStatus.saving) return;
    final generation = ++_generation;
    final draft = state.draft;
    emit(
      DiscountSettingsState(
        status: DiscountSettingsStatus.loading,
        saved: state.saved,
        draft: draft,
        requiresReview: conflict || state.requiresReview,
      ),
    );
    try {
      final saved = await repository.read();
      if (isClosed || generation != _generation) return;
      emit(
        DiscountSettingsState(
          status: conflict
              ? DiscountSettingsStatus.conflict
              : DiscountSettingsStatus.loaded,
          saved: saved,
          draft: preserveDraft ? draft : saved.draft,
          requiresReview: conflict || state.requiresReview,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final denied =
          e is ApiException && (e.statusCode == 403 || e.statusCode == 401);
      emit(
        DiscountSettingsState(
          status: denied
              ? DiscountSettingsStatus.forbidden
              : DiscountSettingsStatus.failure,
          saved: denied ? null : state.saved,
          draft: denied ? const DiscountSettingsDraft() : draft,
          requiresReview: conflict || state.requiresReview,
          errorCode: 'load',
        ),
      );
    }
  }

  void update(DiscountSettingsDraft draft) {
    if (isClosed ||
        state.saved == null ||
        state.status == DiscountSettingsStatus.saving ||
        state.status == DiscountSettingsStatus.loading ||
        state.status == DiscountSettingsStatus.forbidden) {
      return;
    }
    emit(
      DiscountSettingsState(
        saved: state.saved,
        draft: draft,
        status: state.requiresReview
            ? DiscountSettingsStatus.conflict
            : DiscountSettingsStatus.loaded,
        requiresReview: state.requiresReview,
      ),
    );
  }

  void resetDraft() => update(const DiscountSettingsDraft());
  void acknowledgeConflict() {
    if (isClosed ||
        state.saved == null ||
        state.status != DiscountSettingsStatus.conflict) {
      return;
    }
    emit(
      DiscountSettingsState(
        status: DiscountSettingsStatus.loaded,
        saved: state.saved,
        draft: state.draft,
      ),
    );
  }

  void revoke() {
    if (isClosed) return;
    ++_generation;
    emit(const DiscountSettingsState(status: DiscountSettingsStatus.forbidden));
  }

  Future<void> save() async {
    if (isClosed || !state.canSave) return;
    final generation = ++_generation;
    final saved = state.saved!;
    final draft = state.draft;
    emit(
      DiscountSettingsState(
        status: DiscountSettingsStatus.saving,
        saved: saved,
        draft: draft,
      ),
    );
    try {
      final result = await repository.save(draft, saved.version);
      if (isClosed || generation != _generation) return;
      emit(
        DiscountSettingsState(
          status: DiscountSettingsStatus.loaded,
          saved: result,
          draft: result.draft,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final denied =
          e is ApiException && (e.statusCode == 403 || e.statusCode == 401);
      emit(
        DiscountSettingsState(
          status: denied
              ? DiscountSettingsStatus.forbidden
              : DiscountSettingsStatus.failure,
          saved: denied ? null : saved,
          draft: denied ? const DiscountSettingsDraft() : draft,
          errorCode: 'save',
        ),
      );
      if (e is! ApiException ||
          e.statusCode == null ||
          e.code == 'DISCOUNT_SETTINGS_VERSION_CONFLICT') {
        await load(preserveDraft: true, conflict: true);
      }
    }
  }
}
