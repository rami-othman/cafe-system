import 'package:equatable/equatable.dart';

import '../models/customer_failure.dart';
import '../models/customer_import_models.dart';

enum CustomerImportCubitStatus {
  initial,
  previewing,
  ready,
  committing,
  polling,
  success,
  failure,
}

class CustomerImportState extends Equatable {
  const CustomerImportState({
    this.status = CustomerImportCubitStatus.initial,
    this.importStatus,
    this.failure,
  });

  final CustomerImportCubitStatus status;
  final CustomerImportStatus? importStatus;
  final CustomerFailure? failure;

  CustomerImportState copyWith({
    CustomerImportCubitStatus? status,
    CustomerImportStatus? importStatus,
    CustomerFailure? failure,
    bool clearFailure = false,
  }) => CustomerImportState(
    status: status ?? this.status,
    importStatus: importStatus ?? this.importStatus,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => <Object?>[status, importStatus, failure];
}
