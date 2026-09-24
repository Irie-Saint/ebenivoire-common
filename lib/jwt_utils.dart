import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class JWTUtils {
  /// Parse JWT payload from token string
  static Map<String, dynamic>? parseJWTPayload(String token) {
    try {
      debugPrint('🔍 Parsing JWT payload for token validation');

      if (token.isEmpty) {
        debugPrint('❌ Empty token provided');
        return null;
      }

      // JWT structure: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint(
          '❌ Invalid JWT format - expected 3 parts, got ${parts.length}',
        );
        return null;
      }

      // Get payload (second part)
      String payload = parts[1];

      // Add padding if needed for base64 decoding
      switch (payload.length % 4) {
        case 0:
          break; // No padding needed
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
        default:
          debugPrint('❌ Invalid base64 string');
          return null;
      }

      // Decode base64
      final Uint8List bytes = base64Url.decode(payload);
      final String jsonString = utf8.decode(bytes);

      // Parse JSON
      final Map<String, dynamic> decodedPayload = json.decode(jsonString);

      debugPrint('✅ JWT payload parsed successfully');
      debugPrint('📝 Payload contains: ${decodedPayload.keys.join(', ')}');

      return decodedPayload;
    } catch (e) {
      debugPrint('❌ Error parsing JWT payload: $e');
      return null;
    }
  }

  /// Get JWT expiration timestamp (seconds since epoch)
  static int? getJWTExpiry(String token) {
    try {
      final payload = parseJWTPayload(token);
      if (payload == null) {
        debugPrint('❌ Cannot get expiry - invalid payload');
        return null;
      }

      final expiry = payload['exp'];
      if (expiry == null) {
        debugPrint('❌ No expiry field found in JWT payload');
        return null;
      }

      // Convert to int if it's not already
      final int expiryTimestamp = expiry is int
          ? expiry
          : int.parse(expiry.toString());

      debugPrint('📅 JWT expires at timestamp: $expiryTimestamp');
      return expiryTimestamp;
    } catch (e) {
      debugPrint('❌ Error getting JWT expiry: $e');
      return null;
    }
  }

  /// Check if JWT token is expired
  static bool isJWTExpired(String token) {
    try {
      final expiryTimestamp = getJWTExpiry(token);
      if (expiryTimestamp == null) {
        debugPrint('❌ Cannot determine expiry - treating as expired');
        return true; // Treat invalid tokens as expired
      }

      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Add 30 second buffer to account for clock skew
      final isExpired = currentTimestamp >= (expiryTimestamp - 30);

      if (isExpired) {
        final timeDiff = currentTimestamp - expiryTimestamp;
        debugPrint('🔴 JWT is EXPIRED (expired ${timeDiff}s ago)');
        debugPrint('   Current: $currentTimestamp, Expiry: $expiryTimestamp');
      } else {
        final timeRemaining = expiryTimestamp - currentTimestamp;
        debugPrint('🟢 JWT is VALID (expires in ${timeRemaining}s)');
      }

      return isExpired;
    } catch (e) {
      debugPrint('❌ Error checking JWT expiry: $e');
      return true; // Treat errors as expired for security
    }
  }

  /// Get time until JWT expiry in minutes
  static int getTimeUntilExpiry(String token) {
    try {
      final expiryTimestamp = getJWTExpiry(token);
      if (expiryTimestamp == null) {
        debugPrint('❌ Cannot determine expiry time');
        return 0; // Return 0 if we can't determine expiry
      }

      final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final secondsUntilExpiry = expiryTimestamp - currentTimestamp;

      // Convert seconds to minutes
      final minutesUntilExpiry = (secondsUntilExpiry / 60).ceil();

      // Return 0 if already expired or negative
      final timeRemaining = minutesUntilExpiry > 0 ? minutesUntilExpiry : 0;

      debugPrint('⏰ Time until JWT expiry: $timeRemaining minutes');
      return timeRemaining;
    } catch (e) {
      debugPrint('❌ Error calculating time until expiry: $e');
      return 0; // Return 0 on error
    }
  }

  /// Check if JWT is near expiry (within specified minutes)
  static bool isJWTNearExpiry(String token, {int warningMinutes = 2}) {
    try {
      final minutesRemaining = getTimeUntilExpiry(token);
      final isNearExpiry =
          minutesRemaining <= warningMinutes && minutesRemaining > 0;

      if (isNearExpiry) {
        debugPrint(
          '⚠️ JWT is NEAR EXPIRY ($minutesRemaining minutes remaining)',
        );
      }

      return isNearExpiry;
    } catch (e) {
      debugPrint('❌ Error checking if JWT near expiry: $e');
      return false;
    }
  }

  /// Get user ID from JWT payload
  static String? getUserIdFromJWT(String token) {
    try {
      final payload = parseJWTPayload(token);
      if (payload == null) return null;

      // Try different possible user ID fields
      final userId =
          payload['id'] ??
          payload['user_id'] ??
          payload['sub'] ??
          payload['data']?['user']?['id'];

      return userId?.toString();
    } catch (e) {
      debugPrint('❌ Error extracting user ID from JWT: $e');
      return null;
    }
  }

  /// Get user email from JWT payload
  static String? getUserEmailFromJWT(String token) {
    try {
      final payload = parseJWTPayload(token);
      if (payload == null) return null;

      // Try different possible email fields
      final email =
          payload['email'] ??
          payload['user_email'] ??
          payload['data']?['user']?['email'];

      return email?.toString();
    } catch (e) {
      debugPrint('❌ Error extracting email from JWT: $e');
      return null;
    }
  }

  /// Validate JWT token structure without checking expiry
  static bool isValidJWTStructure(String token) {
    try {
      if (token.isEmpty) return false;

      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Try to parse payload
      final payload = parseJWTPayload(token);
      return payload != null;
    } catch (e) {
      debugPrint('❌ Invalid JWT structure: $e');
      return false;
    }
  }

  /// Get formatted expiry date string
  static String getFormattedExpiryDate(String token) {
    try {
      final expiryTimestamp = getJWTExpiry(token);
      if (expiryTimestamp == null) return 'Unknown';

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        expiryTimestamp * 1000,
      );
      return '${expiryDate.day}/${expiryDate.month}/${expiryDate.year} ${expiryDate.hour}:${expiryDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('❌ Error formatting expiry date: $e');
      return 'Invalid';
    }
  }

  /// Debug method to print all JWT information
  static void debugJWTInfo(String token) {
    debugPrint('\n🔍 === JWT DEBUG INFO ===');
    debugPrint('Token length: ${token.length}');
    debugPrint('Valid structure: ${isValidJWTStructure(token)}');
    debugPrint('Is expired: ${isJWTExpired(token)}');
    debugPrint('Time until expiry: ${getTimeUntilExpiry(token)} minutes');
    debugPrint('Is near expiry: ${isJWTNearExpiry(token)}');
    debugPrint('Has user ID: ${getUserIdFromJWT(token)?.isNotEmpty == true}');
    debugPrint(
      'Has user email: ${getUserEmailFromJWT(token)?.isNotEmpty == true}',
    );
    debugPrint('Expiry date: ${getFormattedExpiryDate(token)}');

    final payload = parseJWTPayload(token);
    if (payload != null) {
      debugPrint('Payload keys: ${payload.keys.join(', ')}');
    }
    debugPrint('=== END JWT DEBUG ===\n');
  }
}
