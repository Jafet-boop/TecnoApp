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

        if (loginData['success'] != null &&
            loginData['success']['token'] != null) {
          final token = loginData['success']['token'];

          // endpoint: /users/login/{login}
          final userResponse = await http.get(
            Uri.parse('${AppConstants.baseUrl}/users/login/$username'),
            headers: {
              'DOLAPIKEY': token,
              'Accept': 'application/json',
            },
          );

          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);
            userData['token'] = token;

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
                  'Error al obtener datos del usuario: ${userResponse.statusCode}',
            };
          }
        } else {
          return {'success': false, 'message': 'Credenciales incorrectas'};
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
      if (e.toString().contains('SocketException')) {
        return {
          'success': false,
          'message':
              'No se puede conectar al servidor.\n¿Estás en la misma red WiFi?',
        };
      } else if (e.toString().contains('Timeout')) {
        return {
          'success': false,
          'message':
              'Tiempo de espera agotado.\nVerifica que el servidor esté funcionando.',
        };
      } else {
        return {'success': false, 'message': 'Error: ${e.toString()}'};
      }
    }
  }
}