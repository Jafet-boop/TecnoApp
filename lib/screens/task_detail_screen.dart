import 'package:flutter/material.dart';
import '../services/project_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final String token;
  final Map<String, dynamic> userData;
  final Map<String, dynamic> project;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.token,
    required this.userData,
    required this.project,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _fullTask;
  bool _isLoading = true;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFullTask();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFullTask() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      ProjectService.getTaskById(
        token: widget.token,
        taskId: widget.task['id'].toString(),
      ),
      ProjectService.getUsers(widget.token),
    ]);

    final data = results[0] as Map<String, dynamic>?;
    final users = results[1] as List<dynamic>;

    if (data != null) {
      print('🔑 Campos de la tarea: ${data.keys.toList()}');
      print('⏱️ lines: ${data['lines']}');

      // 🔥 CALCULAR PROGRESO AQUÍ
      final planned =
          int.tryParse(data['planned_workload']?.toString() ?? '0') ?? 0;

      final effective =
          int.tryParse(data['duration_effective']?.toString() ?? '0') ?? 0;

      double progress = 0;

      if (planned > 0) {
        progress = (effective / planned) * 100;
      }

      print('📊 Progreso calculado: $progress');

      // 🔥 GUARDARLO EN EL OBJETO
      data['progress_calculated'] = progress;
    }

    setState(() {
      _fullTask = data ?? widget.task;
      _users = users;
      _isLoading = false;
    });
  }

  Color _statusColor(String? s) {
    switch (s) {
      case '0':
        return Colors.grey;
      case '1':
        return Colors.blue;
      case '2':
        return Colors.green;
      case '3':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
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

  Color _priorityColor(String? p) {
    switch (p) {
      case '1':
        return Colors.orange;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(String? p) {
    switch (p) {
      case '1':
        return 'Alta';
      case '2':
        return 'Urgente';
      default:
        return 'Normal';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null || timestamp == '') return 'N/A';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp.toString()) * 1000,
      );
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null || seconds == '0' || seconds == 0) return '0 min';
    try {
      final total = int.parse(seconds.toString());
      final h = total ~/ 3600;
      final m = (total % 3600) ~/ 60;
      if (h > 0) return '$h h ${m > 0 ? '$m min' : ''}';
      return '$m min';
    } catch (_) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _fullTask ?? widget.task;
    final status = (task['statut'] ?? task['status'])?.toString();
    final priority = task['priority']?.toString();
    double progress = (task['progress_calculated'] ?? 0).toDouble();
    final color = _statusColor(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          task['label'] ?? 'Tarea',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionsMenu(context, status),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Detalle'),
            Tab(icon: Icon(Icons.timer), text: 'Tiempo'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDetailTab(task, status, color, progress, priority),
                _buildTimeTab(task),
              ],
            ),
    );
  }

  // ── Pestaña Detalle ───────────────────────────────────────────────────────
  Widget _buildDetailTab(
    Map<String, dynamic> task,
    String? status,
    Color color,
    double progress,
    String? priority,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card principal ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proyecto
                Row(
                  children: [
                    const Icon(Icons.folder_open, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      widget.project['title'] ?? 'N/A',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Título
                Text(
                  task['label'] ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Prioridad
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _priorityColor(priority).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            priority == '2'
                                ? Icons.priority_high
                                : priority == '1'
                                ? Icons.arrow_upward
                                : Icons.remove,
                            size: 12,
                            color: _priorityColor(priority),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _priorityLabel(priority),
                            style: TextStyle(
                              fontSize: 12,
                              color: _priorityColor(priority),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Barra de progreso
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
                      '${progress.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: progress >= 100
                            ? Colors.green
                            : const Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Descripción ─────────────────────────────────────
          if (task['description'] != null &&
              task['description'].toString().isNotEmpty)
            _buildSection(
              title: 'Descripción',
              icon: Icons.description,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    task['description'],
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // ── Fechas y tiempo ─────────────────────────────────
          _buildSection(
            title: 'Fechas y Tiempo',
            icon: Icons.calendar_today,
            children: [
              _buildInfoRow(
                'Inicio programado',
                _formatDate(task['date_start']),
              ),
              const Divider(height: 1),
              _buildInfoRow('Fin programado', _formatDate(task['date_end'])),
              const Divider(height: 1),
              _buildInfoRow(
                'Tiempo estimado',
                _formatDuration(task['planned_workload']),
              ),
              if (task['date_debut_reel'] != null &&
                  task['date_debut_reel'].toString().isNotEmpty) ...[
                const Divider(height: 1),
                _buildInfoRow(
                  'Inicio real',
                  _formatDate(task['date_debut_reel']),
                ),
              ],
            ],
          ),

          // ── Nota privada ────────────────────────────────────
          if (task['note_private'] != null &&
              task['note_private'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSection(
              title: 'Nota Privada',
              icon: Icons.lock,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(task['note_private']),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Pestaña Tiempo ────────────────────────────────────────────────────────
  Widget _buildTimeTab(Map<String, dynamic> task) {
    final timeLogs = (task['lines'] as List<dynamic>?) ?? [];
    return Column(
      children: [
        // Botón agregar tiempo
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddTimeDialog(task),
              icon: const Icon(Icons.add_alarm),
              label: const Text(
                'Agregar Tiempo Invertido',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        // Lista de tiempos
        Expanded(
          child: timeLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_off, size: 70, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Sin registros de tiempo',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega el tiempo invertido en esta tarea',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: timeLogs.length,
                  itemBuilder: (context, index) {
                    final log = timeLogs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.07),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      // ✅ Correcto — usar campos timespent_line_*
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.timer,
                            color: Color(0xFF1565C0),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          _formatDuration(log['timespent_line_duration']), // ✅
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (log['timespent_line_note'] != null &&
                                log['timespent_line_note']
                                    .toString()
                                    .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  log['timespent_line_note'], // ✅
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Usuario
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Builder(
                                    builder: (context) {
                                      final userId =
                                          log['timespent_line_fk_user']
                                              ?.toString();
                                      final user = _users.firstWhere(
                                        (u) => u['id'].toString() == userId,
                                        orElse: () => {},
                                      );
                                      final name = user.isNotEmpty
                                          ? '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'
                                                .trim()
                                          : 'Usuario $userId';
                                      return Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          _formatDate(
                            log['timespent_line_date'],
                          ), // ✅ timestamp Unix
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Menú de acciones ──────────────────────────────────────────────────────
  void _showActionsMenu(BuildContext context, String? status) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 16),
              child: Text(
                '¿Qué desea hacer?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // Actualizar progreso
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF1565C0),
                child: Icon(Icons.trending_up, color: Colors.white),
              ),
              title: const Text('Actualizar Progreso'),
              subtitle: const Text('Cambiar % de avance y estado'),
              onTap: () {
                Navigator.pop(context);
                _showUpdateProgressDialog();
              },
            ),

            // Agregar tiempo
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.add_alarm, color: Colors.white),
              ),
              title: const Text('Agregar Tiempo'),
              subtitle: const Text('Registrar tiempo invertido'),
              onTap: () {
                Navigator.pop(context);
                _showAddTimeDialog(_fullTask ?? widget.task);
              },
            ),

            // Nota privada
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.edit_note, color: Colors.white),
              ),
              title: const Text('Editar Nota'),
              subtitle: const Text('Agregar nota privada'),
              onTap: () {
                Navigator.pop(context);
                _showEditNoteDialog();
              },
            ),

            // Eliminar
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete, color: Colors.white),
              ),
              title: const Text(
                'Eliminar Tarea',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Esta acción no se puede deshacer'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showUpdateProgressDialog() {
    final task = _fullTask ?? widget.task;
    final validStatuses = ['0', '1', '2', '3'];
    String status = task['status']?.toString() ?? '1';
    if (!validStatuses.contains(status)) status = '1';
    String progress = task['progress']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Actualizar Progreso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Estado
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '0', child: Text('Borrador')),
                  DropdownMenuItem(value: '1', child: Text('En curso')),
                  DropdownMenuItem(value: '3', child: Text('Cerrada')),
                  DropdownMenuItem(value: '2', child: Text('Finalizada')),
                ],
                onChanged: (v) => setDialogState(() {
                  status = v!;
                  if (status == '2') progress = '100';
                }),
              ),

              const SizedBox(height: 16),

              // Progreso
              Text(
                'Progreso: $progress%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: double.parse(progress),
                min: 0,
                max: 100,
                divisions: 20,
                label: '${double.parse(progress).toStringAsFixed(0)}%',
                activeColor: const Color(0xFF1565C0),
                onChanged: (v) =>
                    setDialogState(() => progress = v.toInt().toString()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateProgress(status, progress);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTimeDialog(Map<String, dynamic> task) {
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    final durationController = TextEditingController(text: '1');
    final noteController = TextEditingController();

    // Usuario seleccionado — por defecto el logueado
    String selectedUserId = widget.userData['id']?.toString() ?? '1';
    String selectedUserName =
        '${widget.userData['firstname'] ?? ''} ${widget.userData['lastname'] ?? ''}'
            .trim();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_alarm, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text('Agregar Tiempo'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ Selector de empleado
                if (_users.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Empleado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedUserId,
                            isExpanded: true,
                            items: _users.map((user) {
                              final id = user['id'].toString();
                              final firstName = user['firstname'] ?? '';
                              final lastName = user['lastname'] ?? '';
                              final job = user['job'] ?? '';
                              final name = '$firstName $lastName'.trim();
                              return DropdownMenuItem(
                                value: id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(
                                        0xFF1565C0,
                                      ).withOpacity(0.1),
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1565C0),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            name.isNotEmpty
                                                ? name
                                                : 'Sin nombre',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (job.isNotEmpty)
                                            Text(
                                              job,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setDialogState(() {
                                selectedUserId = v!;
                                final user = _users.firstWhere(
                                  (u) => u['id'].toString() == v,
                                  orElse: () => {},
                                );
                                selectedUserName =
                                    '${user['firstname'] ?? ''} ${user['lastname'] ?? ''}'
                                        .trim();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Fecha
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Hora
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() => selectedTime = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Duración
                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duración (horas)',
                    border: OutlineInputBorder(),
                    suffixText: 'horas',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),

                const SizedBox(height: 12),

                // Nota
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Nota',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                final dateStr =
                    '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')} '
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00';

                final hours = double.tryParse(durationController.text) ?? 1;
                final duration = (hours * 3600).toInt();
                final userId = int.tryParse(selectedUserId) ?? 1;

                await _addTimeSpent(
                  taskId: task['id'].toString(),
                  date: dateStr,
                  duration: duration,
                  userId: userId,
                  note: noteController.text,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNoteDialog() {
    final noteController = TextEditingController(
      text: _fullTask?['note_private'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nota Privada'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Nota',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ProjectService.updateTask(
                token: widget.token,
                taskId: widget.task['id'].toString(),
                notePrivate: noteController.text,
              );

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result['success']
                        ? '✅ Nota guardada'
                        : '❌ ${result['message']}',
                  ),
                  backgroundColor: result['success']
                      ? Colors.green
                      : Colors.red,
                ),
              );
              if (result['success']) _loadFullTask();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Operaciones API ───────────────────────────────────────────────────────
  Future<void> _updateProgress(String status, String progress) async {
    final result = await ProjectService.updateTask(
      token: widget.token,
      taskId: widget.task['id'].toString(),
      status: status,
      progress: progress,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success']
              ? '✅ Progreso actualizado'
              : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) _loadFullTask();
  }

  Future<void> _addTimeSpent({
    required String taskId,
    required String date,
    required int duration,
    required int userId,
    required String note,
  }) async {
    final result = await ProjectService.addTimeSpent(
      token: widget.token,
      taskId: taskId,
      date: date,
      duration: duration,
      userId: userId,
      note: note,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] ? '✅ Tiempo registrado' : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) {
      // 🔥 ESPERA a que recargue
      await _loadFullTask();

      // 🔥 FUERZA actualización de UI
      setState(() {});
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Tarea'),
          ],
        ),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ProjectService.deleteTask(
                token: widget.token,
                taskId: widget.task['id'].toString(),
              );

              if (!mounted) return;

              if (result['success']) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Tarea eliminada'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${result['message']}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF1565C0), size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
