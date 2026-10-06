import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/discount_settings_repository.dart';

class DiscountPermissionsState extends Equatable {
  const DiscountPermissionsState({
    this.saved,
    this.draft = const {},
    this.busy = false,
    this.failed = false,
  });
  final Set<String>? saved;
  final Set<String> draft;
  final bool busy, failed;
  @override
  List<Object?> get props => [saved, draft, busy, failed];
}

class DiscountPermissionsCubit extends Cubit<DiscountPermissionsState> {
  DiscountPermissionsCubit(this.repository)
    : super(const DiscountPermissionsState());
  final DiscountSettingsRepository repository;
  Future<void> load() async {
    if (isClosed || state.busy) return;
    emit(const DiscountPermissionsState(busy: true));
    try {
      final grants = await repository.managerPermissions();
      if (!isClosed) {
        emit(
          DiscountPermissionsState(
            saved: Set.unmodifiable(grants),
            draft: Set.unmodifiable(grants),
          ),
        );
      }
    } catch (_) {
      if (!isClosed) emit(const DiscountPermissionsState(failed: true));
    }
  }

  void toggle(String permission, bool enabled) {
    if (isClosed || state.busy || state.saved == null) return;
    final draft = {...state.draft};
    if (enabled) {
      draft.add(permission);
    } else {
      draft.remove(permission);
    }
    emit(
      DiscountPermissionsState(
        saved: state.saved,
        draft: Set.unmodifiable(draft),
      ),
    );
  }

  Future<void> save() async {
    if (isClosed || state.busy || state.saved == null) return;
    final saved = state.saved, draft = state.draft;
    emit(DiscountPermissionsState(saved: saved, draft: draft, busy: true));
    try {
      final grants = await repository.replaceManagerPermissions(draft);
      if (!isClosed) {
        emit(
          DiscountPermissionsState(
            saved: Set.unmodifiable(grants),
            draft: Set.unmodifiable(grants),
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          DiscountPermissionsState(saved: saved, draft: draft, failed: true),
        );
      }
    }
  }
}
