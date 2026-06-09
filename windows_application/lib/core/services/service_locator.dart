import 'package:get_it/get_it.dart';

import '../../features/pos/controllers/pos_cubit.dart';
import '../../features/pos/repositories/pos_repository.dart';

final GetIt serviceLocator = GetIt.instance;

void setupServiceLocator() {
  if (!serviceLocator.isRegistered<PosRepository>()) {
    serviceLocator.registerLazySingleton<PosRepository>(PosRepository.new);
  }

  if (!serviceLocator.isRegistered<PosCubit>()) {
    serviceLocator.registerFactory<PosCubit>(
      () => PosCubit(repository: serviceLocator<PosRepository>()),
    );
  }
}
