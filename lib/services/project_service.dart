import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ProjectService {
  // ── PROYECTOS ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getProjects(String token) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/projects').replace(
        queryParameters: {
          'sortfield': 't.rowid',
          'sortorder': 'DESC',
          'limit': '100',
        },
      );
      final response = await http.get(
        uri,
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('📁 Projects status: ${response.statusCode}');
      if (response.statusCode == 200) return json.decode(response.body);
      return [];
    } catch (e) {
      print('Error obteniendo proyectos: $e');
      return [];
    }
  }

  static Future<Map<String, List<Map<String, dynamic>>>> getProjectContacts({
    required String token,
    required String projectId,
  }) async {
    try {
      print('📋 Cargando contactos del proyecto $projectId...');

      final response = await http.get(
        Uri.parse(
          '${AppConstants.customUrl}/custom/projectcontacts.php?id=$projectId',
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Error al cargar contactos');
      }

      final List data = json.decode(response.body);

      List<Map<String, dynamic>> internal = [];
      List<Map<String, dynamic>> external = [];

      for (var c in data) {
        if (c['type'] == 'internal') {
          internal.add(Map<String, dynamic>.from(c));
        } else {
          external.add(Map<String, dynamic>.from(c));
        }
      }

      print('✅ Internos: ${internal.length}');
      print('✅ Externos: ${external.length}');

      return {'internal': internal, 'external': external};
    } catch (e) {
      print('❌ Error obteniendo contactos: $e');
      return {'internal': [], 'external': []};
    }
  }

  static Future<Map<String, dynamic>?> getProjectById({
    required String token,
    required String projectId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/projects/$projectId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      print('Error obteniendo proyecto: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getProjectByRef({
    required String token,
    required String ref,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/projects/ref/$ref'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      print('Error obteniendo proyecto por ref: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createProject({
    required String token,
    required String ref,
    required String title,
    required String socid,
    required int dateStart,
    required int dateEnd,
    String description = '',
    String status = '1',
    String isPublic = '1',
    String oppStatus = '1',
  }) async {
    try {
      final body = {
        'ref': ref,
        'title': title,
        'socid': socid,
        'date_start': dateStart,
        'date_end': dateEnd,
        'description': description,
        'status': status,
        'public': isPublic,
        'usage_task': 1,
        'usage_bill_time': 0,
        'opp_status': oppStatus,
      };
      print('📤 Creando proyecto: $body');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/projects'),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      print('Create project status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'project_id': json.decode(response.body).toString(),
          'message': 'Proyecto creado exitosamente',
        };
      } else {
        try {
          final error = json.decode(response.body);
          return {
            'success': false,
            'message': error['error']['message'] ?? 'Error desconocido',
          };
        } catch (_) {
          return {'success': false, 'message': 'Error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProject({
    required String token,
    required String projectId,
    String? title,
    String? status,
    String? notePublic,
    String? notePrivate,
    String? oppStatus,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (title != null) body['title'] = title;
      if (status != null) body['status'] = status;
      if (notePublic != null) body['note_public'] = notePublic;
      if (notePrivate != null) body['note_private'] = notePrivate;
      if (oppStatus != null) body['opp_status'] = oppStatus;
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/projects/$projectId'),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      print('Update project status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Proyecto actualizado'};
      }
      return {'success': false, 'message': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> validateProject({
    required String token,
    required String projectId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/projects/$projectId/validate'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('Validate project status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Proyecto validado'};
      }
      return {'success': false, 'message': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteProject({
    required String token,
    required String projectId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/projects/$projectId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('Delete project status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Proyecto eliminado'};
      }
      return {'success': false, 'message': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<List<dynamic>> getProjectRoles({
    required String token,
    required String projectId,
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/projects/$projectId/roles?userid=$userId',
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }

      return [];
    } catch (e) {
      print('Error obteniendo roles: $e');
      return [];
    }
  }

  // ── TAREAS ────────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getAllTasks(String token) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}/tasks');

      final response = await http.get(
        uri,
        headers: {'DOLAPIKEY': token, 'Content-Type': 'application/json'},
      );

      print('Tasks status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting tasks: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getProjectTasks({
    required String token,
    required String projectId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/projects/$projectId/tasks',
        ).replace(queryParameters: {'includetimespent': '1'}),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('Tasks status: ${response.statusCode}');
      if (response.statusCode == 200) return json.decode(response.body);
      return [];
    } catch (e) {
      print('Error obteniendo tareas: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getTaskById({
    required String token,
    required String taskId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${AppConstants.baseUrl}/tasks/$taskId',
        ).replace(queryParameters: {'includetimespent': '2'}),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('Task by ID status: ${response.statusCode}');
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      print('Error obteniendo tarea: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> createTask({
    required String token,
    required String label,
    required String fkProject,
    required String description,
    required int dateStart,
    required int dateEnd,
    required int plannedWorkload,
    String status = '0',
    String progress = '0',
    String priority = '0',
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final body = {
        'ref': 'TAREA-$timestamp',
        'label': label,
        'fk_project': fkProject,
        'description': description,
        'date_start': dateStart,
        'date_end': dateEnd,
        'planned_workload': plannedWorkload.toString(),
        'status': status,
        'progress': progress,
        'priority': priority,
      };
      print('📤 Creando tarea: $body');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/tasks'),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      print('Create task status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'task_id': json.decode(response.body).toString(),
          'message': 'Tarea creada exitosamente',
        };
      } else {
        try {
          final error = json.decode(response.body);
          return {
            'success': false,
            'message': error['error']['message'] ?? 'Error desconocido',
          };
        } catch (_) {
          return {
            'success': false,
            'message': 'Error: ${response.statusCode}\n${response.body}',
          };
        }
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateTask({
    required String token,
    required String taskId,
    String? progress,
    String? status,
    String? notePrivate,
    int? dateDebutReel,
    int? plannedWorkload,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (progress != null) body['progress'] = progress;
      if (status != null) body['status'] = status;
      if (notePrivate != null) body['note_private'] = notePrivate;
      if (dateDebutReel != null) body['date_debut_reel'] = dateDebutReel;
      if (plannedWorkload != null)
        body['planned_workload'] = plannedWorkload.toString();
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/tasks/$taskId'),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      print('Update task status: ${response.statusCode}');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarea actualizada'};
      }
      return {'success': false, 'message': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteTask({
    required String token,
    required String taskId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/tasks/$taskId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tarea eliminada'};
      }
      return {'success': false, 'message': 'Error: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addTimeSpent({
    required String token,
    required String taskId,
    required String date,
    required int duration,
    required int userId,
    String note = '',
  }) async {
    try {
      final body = {
        'date': date,
        'duration': duration,
        'user_id': userId,
        'note': note,
      };
      print('📤 Agregando tiempo: $body');
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/tasks/$taskId/addtimespent'),
        headers: {
          'DOLAPIKEY': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      print('Add time status: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Tiempo agregado correctamente'};
      }
      return {
        'success': false,
        'message': 'Error: ${response.statusCode}\n${response.body}',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> addTimeAndUpdateProgress({
    required String token,
    required String taskId,
    required String date,
    required int duration,
    required int userId,
    String note = '',
  }) async {
    try {
      // 1️⃣ Agregar tiempo (usa tu función actual)
      final addResult = await addTimeSpent(
        token: token,
        taskId: taskId,
        date: date,
        duration: duration,
        userId: userId,
        note: note,
      );

      if (addResult['success'] != true) {
        return addResult;
      }

      // 2️⃣ Obtener tarea actualizada
      final task = await getTaskById(token: token, taskId: taskId);

      if (task == null) {
        return {'success': false, 'message': 'No se pudo obtener la tarea'};
      }

      // 3️⃣ Calcular progreso
      final planned =
          int.tryParse(task['planned_workload']?.toString() ?? '0') ?? 0;

      int spent = 0;

      if (task['timespent'] != null) {
        if (task['timespent'] is List) {
          spent = task['timespent'].fold(
            0,
            (sum, item) => sum + (item['duration'] ?? 0) as int,
          );
        } else {
          spent = task['timespent'] ?? 0;
        }
      }

      final progress = planned > 0
          ? ((spent / planned) * 100).clamp(0, 100).toInt()
          : 0;

      print('📊 Planned: $planned');
      print('⏱ Spent: $spent');
      print('📈 Progress: $progress%');

      // 4️⃣ Actualizar progreso
      final updateResult = await updateTask(
        token: token,
        taskId: taskId,
        progress: progress.toString(),
      );

      return updateResult;
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  static Future<List<dynamic>> getUsers(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/users').replace(
          queryParameters: {
            'sortfield': 't.rowid',
            'sortorder': 'ASC',
            'limit': '100',
          },
        ),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      print('Users status: ${response.statusCode}');
      if (response.statusCode == 200) return json.decode(response.body);
      return [];
    } catch (e) {
      print('Error obteniendo usuarios: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getUserById({
    required String token,
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/users/$userId'),
        headers: {'DOLAPIKEY': token, 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) return json.decode(response.body);
      return null;
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return null;
    }
  }
}
