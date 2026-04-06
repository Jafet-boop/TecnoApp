import 'package:flutter/material.dart';
import '../services/project_service.dart';
import 'project_detail_screen.dart';
import 'create_project_screen.dart';
import 'MytaskScreen.dart';

class ProjectsListScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const ProjectsListScreen({
    super.key,
    required this.token,
    required this.userData,
  });

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  List<dynamic> _projects = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': null, 'label': 'Todos', 'color': Colors.grey},
    {'value': '1', 'label': 'Prospecto', 'color': Colors.purple},
    {'value': '2', 'label': 'Por Cotizar', 'color': Colors.orange},
    {'value': '3', 'label': 'Seguimiento', 'color': Colors.blue},
    {'value': '4', 'label': 'Por Atender', 'color': Colors.cyan},
    {'value': '5', 'label': 'En Proceso', 'color': Colors.indigo},
    {'value': '6', 'label': 'Por Cobrar', 'color': Colors.teal},
    {'value': '7', 'label': 'Postventa', 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ProjectService.getProjects(widget.token);
      setState(() {
        _projects = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar proyectos: $e';
        _isLoading = false;
      });
    }
  }

  // Nuevo filtro Pros, En Cotizacion, etc.
  List<dynamic> get _filteredProjects {
    List<dynamic> filtered = _projects;

    if (_selectedStatus != null) {
      filtered = filtered.where((p) {
        return p['opp_status']?.toString() == _selectedStatus;
      }).toList();
    }

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final ref = (p['ref'] ?? '').toString().toLowerCase();
        final title = (p['title'] ?? '').toString().toLowerCase();
        return ref.contains(query) || title.contains(query);
      }).toList();
    }

    return filtered;
  }

Color _statusColor(String? s) {
  switch (s) {
    case '1': return Colors.purple;
    case '2': return Colors.orange;
    case '3': return Colors.blue;
    case '4': return Colors.cyan;
    case '5': return Colors.indigo;
    case '6': return Colors.teal;
    case '7': return Colors.green;
    default:  return Colors.grey;
  }
}

String _statusLabel(String? s) {
  switch (s) {
    case '1': return 'Prospecto';
    case '2': return 'Por Cotizar';
    case '3': return 'Seguimiento';
    case '4': return 'Por Atender';
    case '5': return 'En Proceso';
    case '6': return 'Por Cobrar';
    case '7': return 'Postventa';
    default:  return 'Sin estado';
  }
}

IconData _statusIcon(String? s) {
  switch (s) {
    case '1': return Icons.person_search;
    case '2': return Icons.request_quote;
    case '3': return Icons.track_changes;
    case '4': return Icons.pending_actions;
    case '5': return Icons.construction;
    case '6': return Icons.payments;
    case '7': return Icons.thumb_up;
    default:  return Icons.help_outline;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: Colors.white,
            child: Column(
              children: [
                // Buscador
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por referencia o título...',
                    prefixIcon: const Icon(Icons.search, color: Colors.blue),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF0F6FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 10),

                // Filtros de status
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusOptions.length,
                    itemBuilder: (context, index) {
                      final option = _statusOptions[index];
                      final isSelected = _selectedStatus == option['value'];
                      final color = option['color'] as Color;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(option['label']),
                          selectedColor: color.withOpacity(0.15),
                          checkmarkColor: color,
                          labelStyle: TextStyle(
                            color: isSelected ? color : Colors.grey[700],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? color : Colors.grey.shade300,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedStatus = option['value']);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Contador
          if (!_isLoading && _errorMessage.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filteredProjects.length} proyecto(s) encontrado(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ),

          // ── Lista ───────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                  )
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadProjects,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _filteredProjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay proyectos',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (_selectedStatus != null ||
                            _searchController.text.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatus = null;
                                _searchController.clear();
                              });
                            },
                            child: const Text('Limpiar filtros'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadProjects,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredProjects.length,
                      itemBuilder: (context, index) {
                        final project = _filteredProjects[index];
                        final status = project['opp_status']?.toString();
                        final color = _statusColor(status);
                        final isPublic = project['public']?.toString() == '1';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetailScreen(
                                    project: project,
                                    token: widget.token,
                                    userData: widget.userData,
                                  ),
                                ),
                              );
                              _loadProjects();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fila superior
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          _statusIcon(status),
                                          color: color,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              project['title'] ?? 'Sin título',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              project['ref'] ?? 'N/A',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),

                                  // Fila inferior
                                  Row(
                                    children: [
                                      // Status badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: color.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      // Público/Privado badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPublic
                                              ? Colors.blue.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPublic
                                                  ? Icons.public
                                                  : Icons.lock,
                                              size: 11,
                                              color: isPublic
                                                  ? Colors.blue
                                                  : Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isPublic ? 'Público' : 'Privado',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isPublic
                                                    ? Colors.blue
                                                    : Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Spacer(),

                                      // Fechas
                                      Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_formatDate(project['date_start'])} → ${_formatDate(project['date_end'])}',
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
      ),

      // ── FAB crear proyecto ────────────────────────────────────
      // ── FABs ─────────────────────────────────────────────────
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Botón Mis Tareas
          FloatingActionButton.extended(
            heroTag: 'fab_tasks',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyTasksScreen(
                    token: widget.token,
                    userData: widget.userData,
                  ),
                ),
              );
            },
            backgroundColor: const Color(0xFF6A1B9A),
            icon: const Icon(Icons.task_alt, color: Colors.white),
            label: const Text(
              'Mis Tareas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Botón Nuevo Proyecto
          FloatingActionButton.extended(
            heroTag: 'fab_project',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateProjectScreen(
                    token: widget.token,
                    userData: widget.userData,
                  ),
                ),
              );
              _loadProjects();
            },
            backgroundColor: const Color(0xFF1565C0),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Nuevo Proyecto',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
