import 'package:flutter/services.dart';

class TrPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Sadece rakamları al
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Max 11 hane (05XXXXXXXXX)
    final clipped = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < clipped.length; i++) {
      buffer.write(clipped[i]);
      if (i == 3 || i == 6 || i == 8) {
        if (i != clipped.length - 1) buffer.write(' ');
      }
    }

    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
