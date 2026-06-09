import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/pos_repository.dart';
import 'pos_state.dart';

class PosCubit extends Cubit<PosState> {
  PosCubit({required this.repository}) : super(const PosState());

  final PosRepository repository;
}
