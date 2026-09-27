import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/factory_currency.dart';
import '../repositories/factory_currency_repository.dart';

class FactoryCurrencyState extends Equatable {
  const FactoryCurrencyState({
    this.selection = const FactoryCurrencySelection(),
    this.loaded = false,
    this.saving = false,
    this.message,
  });
  final FactoryCurrencySelection selection;
  final bool loaded;
  final bool saving;
  final String? message;
  @override
  List<Object?> get props => <Object?>[selection, loaded, saving, message];
}

class FactoryCurrencyCubit extends Cubit<FactoryCurrencyState> {
  FactoryCurrencyCubit(this.repository) : super(const FactoryCurrencyState());
  final FactoryCurrencyRepository repository;
  Future<void> load(int branchId, FactoryCurrencySelection? initial) async {
    try {
      final settings = initial?.currency == 'USD'
          ? initial!
          : await repository.load(branchId);
      final selection = initial == null || initial.currency == 'USD'
          ? settings
          : FactoryCurrencySelection(
              currency: initial.currency,
              rate: settings.rate,
            );
      if (!isClosed) {
        emit(FactoryCurrencyState(selection: selection, loaded: true));
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          FactoryCurrencyState(
            loaded: true,
            message: 'تعذر تحميل إعدادات العملة: $error',
          ),
        );
      }
    }
  }

  void select(FactoryCurrencySelection selection) =>
      emit(FactoryCurrencyState(selection: selection, loaded: true));
  Future<void> save(int branchId) async {
    final selection = state.selection;
    emit(
      FactoryCurrencyState(selection: selection, loaded: true, saving: true),
    );
    try {
      await repository.save(branchId, selection);
      if (!isClosed) {
        emit(
          FactoryCurrencyState(
            selection: selection,
            loaded: true,
            message: 'تم حفظ إعدادات عملة المعمل.',
          ),
        );
      }
    } catch (error) {
      if (!isClosed) {
        emit(
          FactoryCurrencyState(
            selection: selection,
            loaded: true,
            message: 'تعذر الحفظ: $error',
          ),
        );
      }
    }
  }
}
