import 'package:equatable/equatable.dart';

/// Purchasing screens are read-heavy and mostly manage their own local
/// StatefulWidget state (matching the Suppliers/Expenses convention) — this
/// Cubit exists primarily as a DI carrier for the shared [PurchasingRepository]
/// registered via the service locator, not as a central data store.
class PurchasingState extends Equatable {
  const PurchasingState();

  @override
  List<Object?> get props => const <Object?>[];
}
