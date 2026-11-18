import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted, iterated SHA-256 for the 4-digit app lock PIN.
/// The PIN is a privacy lock for the screen, not data encryption.
class PinService {
  const PinService._();

  static const iterations = 20000;

  static String newSalt([Random? random]) {
    final r = random ?? Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }

  static bool verify(String pin, String salt, String expected) {
    final h = hash(pin, salt);
    if (h.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < h.length; i++) {
      diff |= h.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }
}
