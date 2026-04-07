import 'dart:convert';

import 'package:app_tecno/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/project_service.dart';
import 'create_task_screen.dart';
import 'task_detail_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final String token;
  final Map<String, dynamic> userData;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.token,
    required this.userData,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _fullProject;
  List<dynamic> _tasks = [];
  bool _isLoading = true;
  bool _loadingTasks = false;

  // ✅ NUEVO: Contactos
  List<Map<String, dynamic>> _thirdpartyContacts = [];
  List<Map<String, dynamic>> _internalUsers = [];
  bool _loadingContacts = false;
  String? _clientName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFullData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFullData() async {
    setState(() => _isLoading = true);

    final projectData = await ProjectService.getProjectById(
      token: widget.token,
      projectId: widget.project['id'].toString(),
    );

    setState(() {
      _fullProject = projectData ?? widget.project;
      _isLoading = false;
    });

    // Cargar tareas y contactos EN PARALELO
    await Future.wait([_loadTasks(), _loadContacts(), _loadClientName()]);
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);

    final tasks = await ProjectService.getProjectTasks(
      token: widget.token,
      projectId: widget.project['id'].toString(),
    );

    setState(() {
      _tasks = tasks;
      _loadingTasks = false;
    });
  }

  // NUEVO: Cargar contactos del proyecto
  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);

    final result = await ProjectService.getProjectContacts(
      token: widget.token,
      projectId: widget.project['id'].toString(),
    );

    setState(() {
      _internalUsers = result['internal'] ?? [];
      _thirdpartyContacts = result['external'] ?? [];
      _loadingContacts = false;
    });

    print('👥 Internos: ${_internalUsers.length}');
    print('👥 Externos: ${_thirdpartyContacts.length}');
  }

  // ── Helpers de colores/labels ────────────────────────────────────────────
  Color _statusColor(String? s) {
    switch (s) {
      case '1':
        return Colors.purple;
      case '2':
        return Colors.orange;
      case '3':
        return Colors.blue;
      case '4':
        return Colors.cyan;
      case '5':
        return Colors.indigo;
      case '6':
        return Colors.teal;
      case '7':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case '1':
        return 'Prospecto';
      case '2':
        return 'Por Cotizar';
      case '3':
        return 'Seguimiento';
      case '4':
        return 'Por Atender';
      case '5':
        return 'En Proceso';
      case '6':
        return 'Por Cobrar';
      case '7':
        return 'Postventa';
      default:
        return 'Sin estado';
    }
  }

  Color _taskStatusColor(String? s) {
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

  String _taskStatusLabel(String? s) {
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

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final project = _fullProject ?? widget.project;
    final status = project['opp_status']?.toString();
    final color = _statusColor(status);
    final isPublic = project['public']?.toString() == '1';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(project['ref'] ?? 'Proyecto'),
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
            Tab(icon: Icon(Icons.task_alt), text: 'Tareas'),
            Tab(icon: Icon(Icons.contacts), text: 'Contactos'), // ✅ NUEVO
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
                _buildDetailTab(project, status, color, isPublic),
                _buildTasksTab(project),
                _buildContactsTab(), // ✅ NUEVO
              ],
            ),
    );
  }

  // ── Pestaña Detalle ──────────────────────────────────────────────────────
  Widget _buildDetailTab(
    Map<String, dynamic> project,
    String? status,
    Color color,
    bool isPublic,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card principal
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
                Text(
                  project['title'] ?? 'Sin título',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPublic
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPublic ? Icons.public : Icons.lock,
                            size: 12,
                            color: isPublic ? Colors.blue : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPublic ? 'Público' : 'Privado',
                            style: TextStyle(
                              fontSize: 12,
                              color: isPublic ? Colors.blue : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildSection(
            title: 'Información General',
            icon: Icons.info_outline,
            children: [
              _buildInfoRow('Referencia', project['ref'] ?? 'N/A'),
              const Divider(height: 1),
              _buildInfoRow('Cliente', _clientName ?? 'Cargando...'),
              if (project['description'] != null &&
                  project['description'].toString().isNotEmpty) ...[
                const Divider(height: 1),
                _buildInfoRow('Descripción', project['description']),
              ],
            ],
          ),

          const SizedBox(height: 12),

          _buildSection(
            title: 'Fechas',
            icon: Icons.calendar_today,
            children: [
              _buildInfoRow('Inicio', _formatDate(project['date_start'])),
              const Divider(height: 1),
              _buildInfoRow('Fin estimado', _formatDate(project['date_end'])),
              const Divider(height: 1),
              _buildInfoRow('Creación', _formatDate(project['datec'])),
            ],
          ),

          if (project['note_public'] != null &&
              project['note_public'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSection(
              title: 'Nota Pública',
              icon: Icons.visibility,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(project['note_public']),
                ),
              ],
            ),
          ],

          if (project['note_private'] != null &&
              project['note_private'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSection(
              title: 'Nota Privada',
              icon: Icons.lock,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(project['note_private']),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Pestaña Tareas ───────────────────────────────────────────────────────
  Widget _buildTasksTab(Map<String, dynamic> project) {
    return Column(
      children: [
        if (_tasks.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTaskStat('Total', _tasks.length, Colors.grey),
                _buildTaskStat(
                  'En curso',
                  _tasks.where((t) => t['status']?.toString() == '1').length,
                  Colors.blue,
                ),
                _buildTaskStat(
                  'Cerradas',
                  _tasks.where((t) => t['status']?.toString() == '3').length,
                  Colors.red,
                ),
              ],
            ),
          ),

        Expanded(
          child: _loadingTasks
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                )
              : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No hay tareas',
                        style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _goToCreateTask(project),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear primera tarea'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      final taskStatus = (task['statut'] ?? task['status'])
                          ?.toString();
                      final taskColor = _taskStatusColor(taskStatus);
                      double worked =
                          double.tryParse(
                            task['duration_effective']?.toString() ?? '0',
                          ) ??
                          0;

                      double planned =
                          double.tryParse(
                            task['planned_workload']?.toString() ?? '0',
                          ) ??
                          0;

                      double progress = 0;

                      if (planned > 0) {
                        progress = (worked / planned) * 100;
                      }

                      if (progress > 100) progress = 100;
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
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TaskDetailScreen(
                                  task: task,
                                  token: widget.token,
                                  userData: widget.userData,
                                  project: project,
                                ),
                              ),
                            );
                            _loadTasks();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task['label'] ?? 'Sin título',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: taskColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _taskStatusLabel(taskStatus),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: taskColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
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
                                        fontSize: 16,
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
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDuration(task['planned_workload']),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ── ✅ NUEVO: Pestaña Contactos ───────────────────────────────────────────
  Widget _buildContactsTab() {
    if (_loadingContacts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
      );
    }

    if (_thirdpartyContacts.isEmpty && _internalUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.contacts, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay contactos asignados',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            Text(
              'Asigna contactos al proyecto desde Dolibarr',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContacts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Contactos del Cliente ──────────────────────────
          if (_thirdpartyContacts.isNotEmpty) ...[
            _buildContactSectionHeader(
              icon: Icons.business,
              label: 'Contactos del Cliente',
              count: _thirdpartyContacts.length,
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 8),
            ..._thirdpartyContacts.map((contact) {
              final fullName = contact['name'] ?? 'Sin nombre';
              final role = contact['role'] ?? '';

              return _buildContactCard(
                initials: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                avatarColor: const Color(0xFF1565C0),
                name: fullName,
                subtitle: role,
                email: '', // ya no esta
                phone: '', // ya no esta
              );
            }),
            const SizedBox(height: 24),
          ],

          // ── Miembros del Equipo / Internos ─────────────────
          if (_internalUsers.isNotEmpty) ...[
            _buildContactSectionHeader(
              icon: Icons.engineering,
              label: 'Miembros del Equipo',
              count: _internalUsers.length,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            ..._internalUsers.map((user) {
              final fullName = user['name'] ?? 'Sin nombre';
              final role = user['role'] ?? '';

              return _buildContactCard(
                initials: fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                avatarColor: Colors.green.shade700,
                name: fullName,
                subtitle: role,
                email: '',
                phone: '',
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Encabezado de sección de contactos ──────────────────────────────────
  Widget _buildContactSectionHeader({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ── Tarjeta de contacto ──────────────────────────────────────────────────
  Widget _buildContactCard({
    required String initials,
    required Color avatarColor,
    required String name,
    required String subtitle,
    required String email,
    required String phone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: avatarColor.withOpacity(0.15),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: avatarColor,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        phone,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Menú de acciones ─────────────────────────────────────────────────────
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
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.add_task, color: Colors.white),
              ),
              title: const Text('Crear Tarea'),
              subtitle: const Text('Agregar una tarea al proyecto'),
              onTap: () {
                Navigator.pop(context);
                _goToCreateTask(_fullProject ?? widget.project);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.edit_note, color: Colors.white),
              ),
              title: const Text('Editar Notas'),
              subtitle: const Text('Nota pública, privada y estado'),
              onTap: () {
                Navigator.pop(context);
                _showEditNotesDialog();
              },
            ),
            if (status == '0')
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check_circle, color: Colors.white),
                ),
                title: const Text('Validar Proyecto'),
                subtitle: const Text('Cambiar a estado Abierto'),
                onTap: () {
                  Navigator.pop(context);
                  _validateProject();
                },
              ),
            if (status == '1')
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.folder, color: Colors.white),
                ),
                title: const Text('Cerrar Proyecto'),
                subtitle: const Text('Marcar como cerrado'),
                onTap: () {
                  Navigator.pop(context);
                  _closeProject();
                },
              ),
            if (status == '2')
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.folder_open, color: Colors.white),
                ),
                title: const Text('Reabrir Proyecto'),
                subtitle: const Text('Volver a abrir el proyecto'),
                onTap: () {
                  Navigator.pop(context);
                  _reopenProject();
                },
              ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete, color: Colors.white),
              ),
              title: const Text(
                'Eliminar Proyecto',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Esta acción no se puede deshacer'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.purple,
                child: Icon(Icons.track_changes, color: Colors.white),
              ),
              title: const Text('Cambiar Etapa Comercial'),
              subtitle: Text('Actual: ${_statusLabel(status)}'),
              onTap: () {
                Navigator.pop(context);
                _showOppStatusPicker();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Acciones ─────────────────────────────────────────────────────────────
  void _goToCreateTask(Map<String, dynamic> project) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateTaskScreen(token: widget.token, project: project),
      ),
    );
    _loadTasks();
  }

  void _showEditNotesDialog() {
    final publicController = TextEditingController(
      text: _fullProject?['note_public'] ?? '',
    );
    final privateController = TextEditingController(
      text: _fullProject?['note_private'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar Notas'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: publicController,
                decoration: const InputDecoration(
                  labelText: 'Nota pública',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: privateController,
                decoration: const InputDecoration(
                  labelText: 'Nota privada',
                  border: OutlineInputBorder(),
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
              await _updateNotes(publicController.text, privateController.text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadClientName() async {
    final socid = _fullProject?['socid']?.toString();
    if (socid == null || socid.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/thirdparties/$socid'),
        headers: {'DOLAPIKEY': widget.token, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _clientName = data['name'] ?? 'Sin nombre';
        });
      }
    } catch (e) {
      print('Error cargando nombre del cliente: $e');
    }
  }

  Future<void> _updateNotes(String pub, String priv) async {
    final result = await ProjectService.updateProject(
      token: widget.token,
      projectId: widget.project['id'].toString(),
      notePublic: pub,
      notePrivate: priv,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] ? '✅ Notas actualizadas' : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) _loadFullData();
  }

  Future<void> _validateProject() async {
    final result = await ProjectService.validateProject(
      token: widget.token,
      projectId: widget.project['id'].toString(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] ? '✅ Proyecto validado' : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) _loadFullData();
  }

  void _showOppStatusPicker() {
    final project = _fullProject ?? widget.project;
    String currentOppStatus = project['opp_status']?.toString() ?? '1';

    final stages = [
      {'value': '1', 'label': 'Prospecto', 'color': Colors.purple},
      {'value': '2', 'label': 'Por Cotizar', 'color': Colors.orange},
      {'value': '3', 'label': 'Seguimiento', 'color': Colors.blue},
      {'value': '4', 'label': 'Por Atender', 'color': Colors.cyan},
      {'value': '5', 'label': 'En Proceso', 'color': Colors.indigo},
      {'value': '6', 'label': 'Por Cobrar', 'color': Colors.teal},
      {'value': '7', 'label': 'Postventa', 'color': Colors.green},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 👈 permite que crezca más
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'Cambiar Etapa Comercial',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // Lista scrolleable
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: stages.map((stage) {
                      final isSelected = currentOppStatus == stage['value'];
                      final color = stage['color'] as Color;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(Icons.circle, color: color, size: 14),
                        ),
                        title: Text(
                          stage['label'] as String,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected ? color : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: color)
                            : null,
                        onTap: () {
                          setModalState(
                            () => currentOppStatus = stage['value'] as String,
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateOppStatus(currentOppStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Guardar Cambio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateOppStatus(String oppStatus) async {
    final result = await ProjectService.updateProject(
      token: widget.token,
      projectId: widget.project['id'].toString(),
      oppStatus: oppStatus,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success']
              ? '✅ Etapa actualizada a ${_statusLabel(oppStatus)}'
              : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) _loadFullData();
  }

  Future<void> _closeProject() async {
    final result = await ProjectService.updateProject(
      token: widget.token,
      projectId: widget.project['id'].toString(),
      status: '2',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] ? '✅ Proyecto cerrado' : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.orange : Colors.red,
      ),
    );

    if (result['success']) _loadFullData();
  }

  Future<void> _reopenProject() async {
    final result = await ProjectService.updateProject(
      token: widget.token,
      projectId: widget.project['id'].toString(),
      status: '1',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] ? '✅ Proyecto reabierto' : '❌ ${result['message']}',
        ),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) _loadFullData();
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
            Text('Eliminar Proyecto'),
          ],
        ),
        content: const Text(
          '¿Estás seguro? Esta acción eliminará el proyecto y no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ProjectService.deleteProject(
                token: widget.token,
                projectId: widget.project['id'].toString(),
              );

              if (!mounted) return;

              if (result['success']) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Proyecto eliminado'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildTaskStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
}
