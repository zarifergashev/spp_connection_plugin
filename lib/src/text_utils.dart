import 'dart:typed_data';

class TextUtils {
  static const String newlineCR = '\r';
  static const String newlineLF = '\n';
  static const String newlineCRLF = '\r\n';

  /// Convert hex string to bytes
  static Uint8List fromHexString(String hexString) {
    // Remove spaces and convert to uppercase
    final cleanHex = hexString.replaceAll(' ', '').toUpperCase();

    if (cleanHex.length % 2 != 0) {
      throw ArgumentError('Invalid hex string length');
    }

    final bytes = <int>[];
    for (int i = 0; i < cleanHex.length; i += 2) {
      final hexByte = cleanHex.substring(i, i + 2);
      final byte = int.parse(hexByte, radix: 16);
      bytes.add(byte);
    }

    return Uint8List.fromList(bytes);
  }

  /// Convert bytes to hex string
  static String toHexString(Uint8List bytes) {
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(bytes[i].toRadixString(16).toUpperCase().padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Convert control characters to caret notation
  static String toCaretString(String input, {bool keepNewline = true}) {
    final buffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final charCode = char.codeUnitAt(0);

      if (charCode < 32 && (!keepNewline || char != '\n')) {
        // Convert to caret notation (^A, ^B, etc.)
        buffer.write('^');
        buffer.write(String.fromCharCode(charCode + 64));
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Validate hex string format
  static bool isValidHexString(String hexString) {
    final cleanHex = hexString.replaceAll(' ', '');
    final hexRegExp = RegExp(r'^[0-9A-Fa-f]*$');
    return hexRegExp.hasMatch(cleanHex) && cleanHex.length % 2 == 0;
  }

  /// Format hex string with spaces
  static String formatHexString(String hexString) {
    final cleanHex = hexString.replaceAll(' ', '').toUpperCase();
    final buffer = StringBuffer();

    for (int i = 0; i < cleanHex.length; i += 2) {
      if (i > 0) buffer.write(' ');
      if (i + 1 < cleanHex.length) {
        buffer.write(cleanHex.substring(i, i + 2));
      } else {
        buffer.write(cleanHex[i]);
      }
    }

    return buffer.toString();
  }

  /// Remove newline characters based on type
  static String processNewlines(String input, String newlineType) {
    if (newlineType == newlineCRLF) {
      // Replace CRLF with LF to avoid double newlines
      return input.replaceAll(newlineCRLF, newlineLF);
    }
    return input;
  }

  /// Check if string ends with pending carriage return
  static bool hasPendingCarriageReturn(String input) {
    return input.isNotEmpty && input[input.length - 1] == '\r';
  }
}
