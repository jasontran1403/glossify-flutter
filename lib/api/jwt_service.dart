import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JwtService {
  static Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      // No token → return true (guest mode, no check needed)
      if (token == null || token.isEmpty) {
        return true;
      }

      // Check if token is expired
      bool isExpired = JwtDecoder.isExpired(token);

      if (isExpired) {
        return false;
      } else {
        return true;
      }
    } catch (e) {
      print('❌ Error checking token: $e');
      return false;
    }
  }

  /// Clear all authentication data from SharedPreferences
  static Future<void> clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('role');
      await prefs.remove('username');
      await prefs.remove('fullName');
      await prefs.remove('id');
      await prefs.remove('wallet');
      await prefs.remove('fcmToken');
    } catch (e) {
      print('❌ Error clearing auth data: $e');
    }
  }
}