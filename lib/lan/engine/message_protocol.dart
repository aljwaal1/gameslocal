import 'dart:convert';

import '../models/lan_message.dart';

class LanMessageProtocol {
  const LanMessageProtocol._();

  static String encode(LanMessage message) {
    return '${jsonEncode(message.toJson())}\n';
  }

  static LanMessage? decode(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is Map) {
        return LanMessage.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
