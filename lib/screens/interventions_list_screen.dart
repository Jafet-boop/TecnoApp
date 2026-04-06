import 'package:flutter/material.dart';
import 'intervention_detail_screen.dart';
import '../services/dolibarr_service.dart';
import 'seguimiento_screen.dart';

class InterventionsListScreen extends StatefulWidget {
  final String token;

  const InterventionsListScreen({super.key, required this.token});

  @override
  State<InterventionsListScreen> createState() =>
      _InterventionsListScreenState();
}

class _InterventionsListScreenState extends State<InterventionsListScreen> {
  List<dynamic> interventions = [];
  bool isLoading = true;
  String errorMessage = '';

  // Filtros
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus; // null = todos

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': null, 'label': 'Todos', 'color': Colors.grey},
    {'value': '0', 'label': 'Borrador', 'color': Colors.grey},
    {'value': '1', 'label': 'En Curso', 'color': Colors.blue},
    {'value': '2', 'label': 'Facturadas', 'color': Colors.orange},
    {'value': '3', 'label': 'Terminada', 'color': Colors.green},
  ];

  @override
  void initState() {
    super.initState();
    _loadInterventions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInterventions() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final loaded = await DolibarrService.getInterventions(
        widget.token,
        search: _searchController.text.trim(),
        statusFilter: _selectedStatus,
      );
      setState(() {
        interventions = loaded;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error al cargar intervenciones: $e';
        isLoading = false;
      });
    }
  }

  Color _getStatusColor(String? status) {
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

  String _getStatusLabel(String? status) {
    switch (status) {
      case '0':
        return 'Borrador';
      case '1':
        return 'En Curso';
      case '2':
        return 'Facturadas';
      case '3':
        return 'Terminada';
      default:
        return 'Desconocido';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case '0':
        return Icons.edit;
      case '1':
        return Icons.check_circle_outline;
      case '2':
        return Icons.build;
      case '3':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null || timestamp == '') return 'N/A';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp.toString()) * 1000,
      );
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getClientName(dynamic intervention) {
    if (intervention['thirdparty_name'] != null) {
      return intervention['thirdparty_name'];
    }
    if (intervention['socid'] != null) {
      return 'Cliente ID: ${intervention['socid']}';
    }
    return 'Sin cliente';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intervenciones'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          //Boton de seguimiento(PRUEBA)
          IconButton(
            icon: const Icon(Icons.track_changes),
            tooltip: 'Seguimiento',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SeguimientoScreen(token: widget.token),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Buscador ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por referencia o descripción...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadInterventions();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onSubmitted: (_) => _loadInterventions(),
              textInputAction: TextInputAction.search,
            ),
          ),

          // ── Filtros de status ─────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    selectedColor: color.withOpacity(0.2),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: isSelected ? color : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : Colors.grey.shade300,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedStatus = option['value']);
                      _loadInterventions();
                    },
                  ),
                );
              },
            ),
          ),

          // ── Contador de resultados ────────────────────────────
          if (!isLoading && errorMessage.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${interventions.length} intervención(es) encontrada(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
            ),

          // ── Lista ─────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(errorMessage),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInterventions,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : interventions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No hay intervenciones',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
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
                              _loadInterventions();
                            },
                            child: const Text('Limpiar filtros'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadInterventions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: interventions.length,
                      itemBuilder: (context, index) {
                        final intervention = interventions[index];
                        final status = intervention['statut']?.toString(); // ✅

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(status),
                              child: Icon(
                                _getStatusIcon(status),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              intervention['description'] ?? 'Sin descripción',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Ref: ${intervention['ref'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          status,
                                        ).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(status),
                                        ),
                                      ),
                                      child: Text(
                                        _getStatusLabel(status),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.business,
                                      size: 13,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _getClientName(intervention),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 13,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(intervention['datec']),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                if (intervention['fk_project'] != null &&
                                    intervention['fk_project'].toString() !=
                                        '0' &&
                                    intervention['fk_project']
                                        .toString()
                                        .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.folder_open,
                                          size: 13,
                                          color: Color(0xFF1565C0),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Proyecto: ${intervention['project_ref'] ?? 'ID ${intervention['fk_project']}'}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF1565C0),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      InterventionDetailScreen(
                                        intervention: intervention,
                                        token: widget.token,
                                      ),
                                ),
                              );
                              // Recargar al regresar por si hubo cambios
                              _loadInterventions();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
