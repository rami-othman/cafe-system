import 'package:flutter_test/flutter_test.dart';
import 'package:windows_application/features/shift/models/shift_models.dart';

/// M3 regression: a close_type this build does not recognize must never be
/// interpreted as a manual counted close. It must fail safe to `unknown`,
/// which is always uncounted.
void main() {
  group('ShiftCloseMode.fromApi', () {
    test('maps known server values', () {
      expect(ShiftCloseMode.fromApi('manual'), ShiftCloseMode.manual);
      expect(ShiftCloseMode.fromApi('automatic'), ShiftCloseMode.automatic);
      expect(ShiftCloseMode.fromApi('legacy_reconcile'), ShiftCloseMode.legacyReconcile);
    });

    test('null preserves the historical manual-only default', () {
      expect(ShiftCloseMode.fromApi(null), ShiftCloseMode.manual);
    });

    test('an unrecognized close_type fails safe to unknown, never manual', () {
      final ShiftCloseMode mode = ShiftCloseMode.fromApi('future_close_type_v2');

      expect(mode, ShiftCloseMode.unknown);
      expect(mode.isCounted, isFalse);
    });

    test('unknown is never counted, matching automatic/legacy semantics', () {
      expect(ShiftCloseMode.unknown.isCounted, isFalse);
    });
  });
}
