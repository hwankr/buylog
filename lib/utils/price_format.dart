String formatPrice(int price) {
  final sign = price < 0 ? '-' : '';
  final digits = price.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return '$sign$buffer원';
}
