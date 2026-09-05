import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/inventory/bar_checks/bar_check_review_state.dart';
import 'package:windows_application/features/inventory/counts/count_line_state.dart';

void main() {
  test('keeps an entered zero distinct from an uncounted line', () {
    expect(
      countLineState(isCounted: false, varianceStatus: null),
      CountLineState.uncounted,
    );
    expect(
      countLineState(isCounted: true, varianceStatus: 'within_tolerance'),
      CountLineState.counted,
    );
  });

  test('maps variance and manager review states for Bar Check', () {
    expect(
      countLineState(isCounted: true, varianceStatus: 'needs_reason'),
      CountLineState.needsReason,
    );
    expect(
      barCheckReviewState('needs_manager_review', null),
      BarCheckReviewState.pending,
    );
    expect(
      barCheckReviewState('needs_manager_review', 'approved'),
      BarCheckReviewState.approved,
    );
  });
}
