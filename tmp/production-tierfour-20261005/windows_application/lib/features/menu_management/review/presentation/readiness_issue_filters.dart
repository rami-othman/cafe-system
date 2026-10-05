import '../models/review_models.dart';
import 'validation_issue_presentation.dart';

class ReadinessIssueGroup {
  const ReadinessIssueGroup({
    required this.severity,
    required this.category,
    required this.issues,
  });

  final ValidationSeverity severity;
  final ReadinessIssueCategory category;
  final List<ValidationIssue> issues;

  String get key => '${severity.name}:${category.name}';
}

List<ValidationIssue> filterReadinessIssues(
  Iterable<ValidationIssue> issues, {
  ValidationSeverity? severity,
  required String search,
  required String Function(ReadinessIssueCategory category) categoryTitle,
}) {
  final String needle = search.trim().toLowerCase();
  return issues
      .where((ValidationIssue issue) => issue.code != 'NO_ASSIGNED_MENU')
      .where(
        (ValidationIssue issue) =>
            severity == null || issue.severityValue == severity,
      )
      .where((ValidationIssue issue) {
        if (needle.isEmpty) return true;
        final ReadinessIssueCategory category =
            ValidationIssuePresentation.categoryFor(issue);
        return issue.message.toLowerCase().contains(needle) ||
            categoryTitle(category).toLowerCase().contains(needle);
      })
      .toList(growable: false);
}

List<ReadinessIssueGroup> groupReadinessIssues(
  Iterable<ValidationIssue> issues,
) {
  final Map<String, List<ValidationIssue>> grouped =
      <String, List<ValidationIssue>>{};
  for (final ValidationIssue issue in issues) {
    final ValidationSeverity severity = issue.severityValue;
    // The current API contract contains errors and warnings. Keep a future
    // severity visible rather than hiding a backend response.
    final ReadinessIssueCategory category =
        ValidationIssuePresentation.categoryFor(issue);
    final String key = '${severity.name}:${category.name}';
    (grouped[key] ??= <ValidationIssue>[]).add(issue);
  }

  final List<ReadinessIssueGroup> result = <ReadinessIssueGroup>[];
  for (final ValidationSeverity severity in <ValidationSeverity>[
    ValidationSeverity.error,
    ValidationSeverity.warning,
    ValidationSeverity.information,
    ValidationSeverity.unknown,
  ]) {
    for (final ReadinessIssueCategory category
        in ReadinessIssueCategory.values) {
      final List<ValidationIssue>? group =
          grouped['${severity.name}:${category.name}'];
      if (group != null && group.isNotEmpty) {
        result.add(
          ReadinessIssueGroup(
            severity: severity,
            category: category,
            issues: List<ValidationIssue>.unmodifiable(group),
          ),
        );
      }
    }
  }
  return List<ReadinessIssueGroup>.unmodifiable(result);
}
