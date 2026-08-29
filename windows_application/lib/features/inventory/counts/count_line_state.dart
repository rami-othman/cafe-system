/// Small count-domain slice used by count widgets while the legacy screen is
/// progressively split. It keeps the zero-count and uncounted states distinct.
enum CountLineState { uncounted, counted, needsReason, needsManagerReview }

CountLineState countLineState({
  required bool isCounted,
  required String? varianceStatus,
}) {
  if (!isCounted) return CountLineState.uncounted;
  if (varianceStatus == 'needs_manager_review') {
    return CountLineState.needsManagerReview;
  }
  if (varianceStatus == 'needs_reason') return CountLineState.needsReason;
  return CountLineState.counted;
}
