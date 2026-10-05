import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/core/services/service_locator.dart';
import 'package:windows_application/features/cafe_configuration/controllers/cafe_configuration_cubits.dart';

void main() {
  test(
    'registers a fresh BranchEditorCubit for the create-branch route',
    () async {
      await serviceLocator.reset();
      addTearDown(serviceLocator.reset);
      setupServiceLocator(useBackend: false);

      expect(serviceLocator.isRegistered<BranchEditorCubit>(), isTrue);
      expect(serviceLocator<BranchEditorCubit>(), isA<BranchEditorCubit>());
    },
  );
}
