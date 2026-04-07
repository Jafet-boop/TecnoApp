import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final loginResponse = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'login': username,
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout - No se pudo conectar al servidor');
            },
          );

      if (loginResponse.statusCode == 200) {
        final loginData = json.decode(loginResponse.body);

        // 🔥 Obtener token correctamente
        if (loginData['success'] != null &&
            loginData['success']['token'] != null) {

          final token = loginData['success']['token'];

          print("TOKEN OBTENIDO: $token");

          // 🔥 Obtener datos del usuario
          final userResponse = await http.get(
            Uri.parse('${AppConstants.baseUrl}/users/login/$username'),
            headers: {
              'DOLAPIKEY': token,
              'Accept': 'application/json',
            },
          );

          if (userResponse.statusCode == 200) {
            final rawUserData = json.decode(userResponse.body);

            // 🔥 Convertir correctamente el Map
            final userData = Map<String, dynamic>.from(rawUserData);

            // 🔥 Agregar token al usuario
            userData['token'] = token;

            print("USER DATA LIMPIO: $userData");

            return {
              'success': true,
              'user': userData,
              'token': token,
              'message': 'Login exitoso',
            };
          } else {
            return {
              'success': false,
              'message':
                  'Error al obtener usuario: ${userResponse.statusCode}',
            };
          }
        } else {
          return {
            'success': false,
            'message': 'Token no recibido',
          };
        }
      } else if (loginResponse.statusCode == 403) {
        return {
          'success': false,
          'message': 'Usuario o contraseña incorrectos',
        };
      } else {
        return {
          'success': false,
          'message': 'Error del servidor: ${loginResponse.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}