import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/project_service.dart';
import 'task_detail_screen.dart';

class MyTasksScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const MyTasksScreen({super.key, required this.token, required this.userData});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  List<dynamic> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);

    final tasks = await ProjectService.getAllTasks(widget.token);

    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  // FILTRO: MIS TAREAS PENDIENTES
List<dynamic> get _pendingTasks {
  final userId = widget.userData['id'].toString();
  print('🔍 userId: $userId');

  return _tasks.where((task) {
    final status = (task['statut'] ?? task['status'])?.toString();

    final assignedUser =
        task['fk_user_assign']?.toString() ??
        task['fk_user']?.toString() ??
        task['user_id']?.toString() ??
        task['fk_user_creat']?.toString();

    // Debug (Prueba)
    print('📋 Task: ${task['label']} | status: $status | assignedUser: $assignedUser');

    return assignedUser == userId && (status == '0' || status == '1');
  }).toList();
}

  // 🎨 COLOR STATUS
  Color _taskStatusColor(String? status) {
    switch (status) {
      case '0':
        return Colors.grey;
      case '1':
        return Colors.blue;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _taskStatusLabel(String? status) {
    switch (status) {
      case '0':
        return 'Borrador';
      case '1':
        return 'En curso';
      case '2':
        return 'Finalizada';
      case '3':
        return 'Cerrada';
      default:
        return 'Desconocido';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '--';

    final intTime = int.tryParse(timestamp.toString());
    if (intTime == null) return '--';

    final date = DateTime.fromMillisecondsSinceEpoch(intTime * 1000);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null) return '0h';
    final hours = (int.tryParse(seconds.toString()) ?? 0) ~/ 3600;
    return '${hours}h';
  }

  // CÁLCULO DE PROGRESO
  double _calculateProgress(Map task) {
    double worked =
        double.tryParse(task['duration_effective']?.toString() ?? '0') ?? 0;

    double planned =
        double.tryParse(task['planned_workload']?.toString() ?? '0') ?? 0;

    if (planned <= 0) return 0;

    double progress = (worked / planned) * 100;

    return progress > 100 ? 100 : progress;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _pendingTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis tareas pendientes'),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
          ? const Center(child: Text('No tienes tareas pendientes'))
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  final status = (task['statut'] ?? task['status'])?.toString();

                  final color = _taskStatusColor(status);

                  double progress = _calculateProgress(task);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.07),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailScreen(
                              task: task,
                              token: widget.token,
                              userData: widget.userData,
                              project: {},
                            ),
                          ),
                        );
                        _loadTasks();
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['label'] ?? 'Sin título',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // BARRA PROGRESO
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: progress / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    color: progress >= 100
                                        ? Colors.green
                                        : const Color(0xFF1565C0),
                                    minHeight: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${progress.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: progress >= 100
                                      ? Colors.green
                                      : const Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatDate(task['date_start'])} → ${_formatDate(task['date_end'])}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _taskStatusLabel(status),
                                style: TextStyle(color: color),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
