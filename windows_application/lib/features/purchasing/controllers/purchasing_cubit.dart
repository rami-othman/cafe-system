import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/purchasing_repository.dart';
import 'purchasing_state.dart';

class PurchasingCubit extends Cubit<PurchasingState> {
  PurchasingCubit({required this.repository}) : super(const PurchasingState());

  final PurchasingRepository repository;
}
