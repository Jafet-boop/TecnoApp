import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const String _keyUserData = 'userData';
  static const String _keyIsLoggedIn = 'isLoggedIn';

  // Guardar sesión
  static Future<void> saveSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, json.encode(userData));
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // Obtener datos guardados
  static Future<Map<String, dynamic>?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return null;

    final userDataString = prefs.getString(_keyUserData);
    if (userDataString == null) return null;

    return json.decode(userDataString);
  }

  // Cerrar sesión
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserData);
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}