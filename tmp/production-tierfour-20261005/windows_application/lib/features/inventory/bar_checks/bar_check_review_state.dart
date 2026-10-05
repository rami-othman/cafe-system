/// Presentation-safe mapping for the review fields returned by Bar Check APIs.
enum BarCheckReviewState { notRequired, pending, approved, rejected }

BarCheckReviewState barCheckReviewState(
  String? varianceStatus,
  String? managerReviewStatus,
) {
  if (varianceStatus != 'needs_manager_review') {
    return BarCheckReviewState.notRequired;
  }
  return switch (managerReviewStatus) {
    'approved' => BarCheckReviewState.approved,
    'rejected' => BarCheckReviewState.rejected,
    _ => BarCheckReviewState.pending,
  };
}
