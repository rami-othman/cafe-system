import 'package:equatable/equatable.dart';
import '../models/daily_report_data.dart';

enum DailyReportStatus { loading, loaded, empty, error }

class DailyReportState extends Equatable {
  const DailyReportState({
    this.status = DailyReportStatus.loading,
    this.branch = 'DOWNTOWN',
    this.dateLabel = 'Today, Oct 24, 2023',
    this.selectedDate,
    this.data,
    this.errorMessage,
  });
  final DailyReportStatus status;
  final String branch;
  final String dateLabel;
  final DateTime? selectedDate;
  final DailyReportData? data;
  final String? errorMessage;
  DailyReportState copyWith({
    DailyReportStatus? status,
    String? branch,
    String? dateLabel,
    DateTime? selectedDate,
    DailyReportData? data,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) => DailyReportState(
    status: status ?? this.status,
    branch: branch ?? this.branch,
    dateLabel: dateLabel ?? this.dateLabel,
    selectedDate: selectedDate ?? this.selectedDate,
    data: data ?? this.data,
    errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
  );
  @override
  List<Object?> get props => <Object?>[
    status,
    branch,
    dateLabel,
    selectedDate,
    data,
    errorMessage,
  ];
}
