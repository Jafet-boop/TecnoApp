import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';

class DolibarrService {
  // Obtener información de los módulos disponibles
  static Future<Map<String, dynamic>> getModulesInfo(String token) async {
    try {
      // Probar endpoint de intervenciones
      final interventionsResponse = await http.get(
        Uri.parse('${AppConstants.baseUrl}/interventions'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('🔧 Interventions endpoint: ${interventionsResponse.statusCode}');

      // Probar endpoint de terceros (clientes)
      final thirdsResponse = await http.get(
        Uri.parse('${AppConstants.baseUrl}/thirdparties'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('👥 Thirdparties endpoint: ${thirdsResponse.statusCode}');

      return {
        'interventions_available': interventionsResponse.statusCode == 200,
        'thirdparties_available': thirdsResponse.statusCode == 200,
      };
    } catch (e) {
      print('Error verificando módulos: $e');
      return {
        'interventions_available': false,
        'thirdparties_available': false,
      };
    }
  }

  // Obtener clientes/terceros
  static Future<List<dynamic>> getThirdparties(String token) async {
    try {
      List<dynamic> allThirdparties = [];
      int page = 0;
      const int limit = 100;
      bool hasMore = true;

      while (hasMore) {
        final response = await http.get(
          Uri.parse(
            '${AppConstants.baseUrl}/thirdparties?limit=$limit&page=$page&sortfield=t.rowid&sortorder=ASC',
          ),
          headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
        );

        print('Thirdparties page $page - status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);

          if (data.isEmpty) {
            hasMore = false; // Ya no hay más páginas
          } else {
            allThirdparties.addAll(data);
            if (data.length < limit) {
              hasMore = false; // Última página (incompleta)
            } else {
              page++; // Siguiente página
            }
          }
        } else {
          hasMore = false;
        }
      }
      return allThirdparties;
    } catch (e) {
      print('Error obteniendo terceros: $e');
      return [];
    }
  }

  // Obtener lista de intervenciones
  static Future<List<dynamic>> getInterventions(
    String token, {
    String? search,
    String? statusFilter,
    String? refClientfilter,
    int limit = 100, // ✅ subimos el límite para traer todo y filtrar local
    int page = 0,
  }) async {
    try {
      final params = {
        'sortfield': 't.rowid',
        'sortorder': 'DESC',
        'limit': limit.toString(),
        'page': page.toString(),
      };

      final uri = Uri.parse(
        '${AppConstants.baseUrl}/interventions',
      ).replace(queryParameters: params);

      final response = await http.get(
        uri,
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);

        // ✅ Filtro local por status
        if (statusFilter != null && statusFilter.isNotEmpty) {
          data = data.where((i) {
            return i['statut']?.toString() == statusFilter;
          }).toList();
        }

        if (refClientfilter != null && refClientfilter.isNotEmpty) {
          data = data.where((i) {
            final refClient = (i['ref_client'] ?? '').toString().toUpperCase();
            return refClient.startsWith(refClientfilter);
          }).toList();
        }

        // Filtro local por búsqueda
        if (search != null && search.isNotEmpty) {
          data = data.where((i) {
            final ref = (i['ref'] ?? '').toString().toLowerCase();
            final desc = (i['description'] ?? '').toString().toLowerCase();
            final refClient = (i['ref_client'] ?? '').toString().toLowerCase();
            return ref.contains(search.toLowerCase()) ||
                desc.contains(search.toLowerCase()) ||
                refClient.contains(search.toLowerCase());
          }).toList();
        }

        return data;
      } else {
        return [];
      }
    } catch (e) {
      print('Error obteniendo intervenciones: $e');
      return [];
    }
  }

  // Crear intervención (borrador)
  static Future<Map<String, dynamic>> createIntervention({
    required String token,
    required String thirdpartyId,
    String? refClient,
    required String description,
    String? notePublic,
    String? notePrivate,
    String? fkProject,
  }) async {
    try {
      print('📝 Creando intervención (borrador)...');
      print('Cliente ID: $thirdpartyId');
      print('Descripción: $description');

      // Preparar datos
      final Map<String, dynamic> requestData = {
        'socid': thirdpartyId,
        'date': DateTime.now().millisecondsSinceEpoch ~/ 1000, // timestamp Unix
        'description': description,
        'fk_project': fkProject != null ? int.tryParse(fkProject) ?? 0 : 0,
        'fk_contrat': 0,
      };

      // Campos opcionales
      if (refClient != null && refClient.isNotEmpty) {
        requestData['ref_client'] = refClient;
      }
      if (notePublic != null && notePublic.isNotEmpty) {
        requestData['note_public'] = notePublic;
      }
      if (notePrivate != null && notePrivate.isNotEmpty) {
        requestData['note_private'] = notePrivate;
      }

      print('📤 Datos a enviar: $requestData');

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/interventions'),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('Create intervention status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'intervention_id': responseData
              .toString(), // ID de la intervención creada
          'data': responseData,
          'message': 'Intervención creada exitosamente',
        };
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']['message'] ?? 'Error desconocido';
          return {
            'success': false,
            'message': 'Error al crear intervención:\n$errorMsg',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error: ${response.statusCode}\n${response.body}',
          };
        }
      }
    } catch (e) {
      print('Error creando intervención: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<bool> updateInterventionNotes({
    required String token,
    required int interventionId,
    required String notePublic,
    required String notePrivate,
  }) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/interventions/$interventionId'),
      headers: {'DOLAPIKEY': token, 'Content-Type': 'application/json'},
      body: jsonEncode({
        "note_public": notePublic,
        "note_private": notePrivate,
      }),
    );

    print("Update status: ${response.statusCode}");
    print("Response: ${response.body}");

    return response.statusCode == 200;
  }

  // Agregar línea a la intervención (descripción detallada con fecha/hora)
  static Future<Map<String, dynamic>> addInterventionLine({
    required String token,
    required String interventionId,
    required String description,
    String? date,
    String? duration,
  }) async {
    try {
      print('📝 Agregando línea a intervención $interventionId...');

      final Map<String, dynamic> requestData = {
        'description': description,
        'qty': 1,
        'product_type': 1,
      };

      if (date != null && date.isNotEmpty) {
        requestData['date'] = int.tryParse(date) ?? 0; // ✅ int, no string
      }
      if (duration != null && duration.isNotEmpty) {
        requestData['duration'] =
            int.tryParse(duration) ?? 3600; // ✅ int, no string
      }

      print('📤 Datos de línea: $requestData');

      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/interventions/$interventionId/lines',
        ),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestData),
      );

      print('Add line status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Línea agregada exitosamente'};
      } else {
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']['message'] ?? 'Error desconocido';
          return {
            'success': false,
            'message': 'Error al agregar línea:\n$errorMsg',
          };
        } catch (e) {
          return {
            'success': false,
            'message': 'Error: ${response.statusCode}\n${response.body}',
          };
        }
      }
    } catch (e) {
      print('Error agregando línea: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Validar intervención (cambiar de borrador a validado)
  static Future<Map<String, dynamic>> validateIntervention({
    required String token,
    required String interventionId,
  }) async {
    try {
      print('Validando intervención $interventionId...');

      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/interventions/$interventionId/validate',
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Validate status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Intervención validada'};
      } else {
        return {
          'success': false,
          'message': 'Error al validar: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteIntervention({
    required String token,
    required String interventionId,
  }) async {
    try {
      print('🗑 Eliminando intervención $interventionId...');

      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/interventions/$interventionId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Delete status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Intervención eliminada correctamente',
        };
      } else {
        return {
          'success': false,
          'message': 'Error al eliminar: ${response.body}',
        };
      }
    } catch (e) {
      print('Error eliminando intervención: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Obtener contactos de una intervención (PRUEBA)
  static Future<void> exploreInterventionContacts({
    required String token,
    required String interventionId,
  }) async {
    try {
      print('🔍 Explorando contactos de intervención $interventionId...');

      // Probar diferentes endpoints posibles
      final endpoints = [
        '/interventions/$interventionId/contacts',
        '/interventions/$interventionId/contact',
        '/fichinter/$interventionId/contacts',
      ];

      for (final endpoint in endpoints) {
        print('\n📡 Probando: ${AppConstants.baseUrl}$endpoint');

        try {
          final response = await http.get(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
          );

          print('Status: ${response.statusCode}');
          if (response.statusCode == 200) {
            print('✅ FUNCIONA!');
            print('Body: ${response.body}');
          } else {
            print('❌ Error: ${response.body}');
          }
        } catch (e) {
          print('❌ Excepción: $e');
        }
      }
    } catch (e) {
      print('Error general: $e');
    }
  }

  // Obtener UNA intervención específica con todos sus detalles (PRUEBA)
  static Future<Map<String, dynamic>?> getInterventionById({
    required String token,
    required String interventionId,
  }) async {
    try {
      print('🔍 Obteniendo detalles de intervención $interventionId...');

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/interventions/$interventionId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Status: ${response.statusCode}');
      print('Body completo:');
      print(response.body);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Obtener información de un contacto (socpeople)
  static Future<Map<String, dynamic>?> getContactById({
    required String token,
    required String contactId,
  }) async {
    try {
      print('👤 Obteniendo contacto $contactId...');

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/contacts/$contactId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Contact status: ${response.statusCode}');
      print('Contact body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('Error obteniendo contacto: $e');
      return null;
    }
  }

  // Obtener información de un usuario
  static Future<Map<String, dynamic>?> getUserById({
    required String token,
    required String userId,
  }) async {
    try {
      print('👨‍💼 Obteniendo usuario $userId...');

      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/users/$userId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('User status: ${response.statusCode}');
      print('User body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return null;
    }
  }

  // Obtener archivos vinculados (PRUEBA)
  static Future<void> exploreInterventionDocuments({
    required String token,
    required String interventionId,
    required String interventionRef,
  }) async {
    try {
      print('📁 Explorando documentos de intervención $interventionId...');
      print('Ref: $interventionRef');

      // Probar diferentes endpoints
      final endpoints = [
        '/documents?modulepart=ficheinter&id=$interventionId',
        '/documents?modulepart=intervention&id=$interventionId',
        '/documents?modulepart=ficheinter&original_file=$interventionRef',
        '/interventions/$interventionId/documents',
        '/fichinter/$interventionId/documents',
      ];

      for (final endpoint in endpoints) {
        print('\n📡 Probando: ${AppConstants.baseUrl}$endpoint');

        try {
          final response = await http.get(
            Uri.parse('${AppConstants.baseUrl}$endpoint'),
            headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
          );

          print('Status: ${response.statusCode}');
          if (response.statusCode == 200) {
            print('✅ FUNCIONA!');
            print('Body: ${response.body}');
          } else {
            print('❌ Error: ${response.body}');
          }
        } catch (e) {
          print('❌ Excepción: $e');
        }
      }
    } catch (e) {
      print('Error general: $e');
    }
  }

  // Obtener archivos de una intervención
  static Future<List<dynamic>> getInterventionDocuments({
    required String token,
    required String interventionId,
  }) async {
    try {
      print('📁 Obteniendo documentos de intervención $interventionId...');

      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/documents?modulepart=intervention&id=$interventionId',
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Documents status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> documents = json.decode(response.body);
        print('Total documentos: ${documents.length}');
        return documents;
      } else {
        return [];
      }
    } catch (e) {
      print('Error obteniendo documentos: $e');
      return [];
    }
  }

  //Descargar archivos
  static Future<Map<String, dynamic>> downloadDocument({
    required String token,
    required String interventionRef,
    required String filename,
  }) async {
    try {
      print('📥 Descargando archivo: $filename');

      // Construcción de la URL con modulepart=ficheinter
      final url =
          '${AppConstants.baseUrl}/documents/download?modulepart=ficheinter&original_file=$interventionRef/$filename';

      final response = await http.get(
        Uri.parse(url),
        headers: {'DOLAPIKEY': token},
      );

      print('Download status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 1. Convertimos el cuerpo de la respuesta (JSON) a un Map
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // 2. Extraemos el string en Base64 que viene en el campo 'content'
        final String base64Content = jsonResponse['content'];

        // 3. Decodificamos el Base64 a bytes reales de imagen
        final Uint8List imageBytes = base64Decode(
          base64Content.replaceAll(RegExp(r'\s+'), ''),
        );

        if (imageBytes.isEmpty) {
          return {
            'success': false,
            'message': 'El archivo decodificado está vacío',
          };
        }

        String filePath;

        // Lógica de rutas
        if (Platform.isAndroid) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          final dolibarrDir = Directory('${downloadsDir.path}/Dolibarr');

          if (!await dolibarrDir.exists()) {
            await dolibarrDir.create(recursive: true);
          }

          filePath = '${dolibarrDir.path}/$filename';
        } else {
          final directory = await getApplicationDocumentsDirectory();
          filePath = '${directory.path}/$filename';
        }

        // 4. GUARDAR LOS BYTES DECODIFICADOS (imageBytes)
        final file = File(filePath);
        await file.writeAsBytes(imageBytes);

        print('📄 Archivo real guardado: $filePath');
        print('Tamaño real de la imagen: ${imageBytes.length} bytes');

        // Notificar a Android (Media Scanner)
        if (Platform.isAndroid) {
          try {
            await Process.run('am', [
              'broadcast',
              '-a',
              'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
              '-d',
              'file://$filePath',
            ]);
            print('📸 Galería actualizada');
          } catch (e) {
            print('⚠️ No se pudo escanear: $e');
          }
        }

        return {
          'success': true,
          'message': 'Imagen guardada correctamente',
          'filePath': filePath,
        };
      } else {
        return {
          'success': false,
          'message': 'Error de servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error crítico descargando: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Subir un archivo a la intervención
  static Future<Map<String, dynamic>> uploadDocument({
    required String interventionRef,
    required String filePath,
    required String filename,
  }) async {
    try {
      print('📤 Preparando subida: $filename');

      final file = File(filePath);

      if (!await file.exists()) {
        return {
          'success': false,
          'message': 'El archivo no existe en la ruta especificada',
        };
      }

      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(
          'https://control.tecnosolucion.com.mx/public/upload_intervention_image.php',
        ),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'ref': interventionRef,
          'filename': filename,
          'filecontent': base64File,
        },
      );

      print('Upload status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Evidencia subida exitosamente'};
      } else {
        return {
          'success': false,
          'message': 'Error al subir: ${response.body}',
        };
      }
    } catch (e) {
      print('Error crítico subiendo archivo: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Cerrar intervención
  static Future<Map<String, dynamic>> closeIntervention({
    required String token,
    required String interventionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/interventions/$interventionId/close',
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Close status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Intervención cerrada'};
      } else {
        return {
          'success': false,
          'message': 'Error al cerrar: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Reabrir intervención
  static Future<Map<String, dynamic>> reopenIntervention({
    required String token,
    required String interventionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/interventions/$interventionId/reopen',
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      print('Reopen status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Intervención reabierta'};
      } else {
        return {
          'success': false,
          'message': 'Error al reabrir: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
