abstract final class TaxFormatter {
  static String percentLabel(double rate) {
    final String percent = (rate * 100).toStringAsFixed(2);
    return percent
        .replaceFirst(RegExp(r'\.0+$'), '')
        .replaceFirst(RegExp(r'(\.\d*?)0+$'), r'$1');
  }

  static String taxLabel(double rate) => 'Tax (${percentLabel(rate)}%)';
}
