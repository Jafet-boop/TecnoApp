import 'package:app_tecno/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'intervention_detail_screen.dart';
import 'create_intervention_screen.dart';
import '../services/dolibarr_service.dart';
import 'seguimiento_screen.dart';

class InterventionsListScreen extends StatefulWidget {
  final String token;

  const InterventionsListScreen({super.key, required this.token});

  @override
  State<InterventionsListScreen> createState() =>
      _InterventionsListScreenState();
}

class _InterventionsListScreenState extends State<InterventionsListScreen>
    with SingleTickerProviderStateMixin {
  // ── FAB expandable ──────────────────────────────────────────
  bool _fabExpanded = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabRotation;
  late Animation<double> _fabScale;

  // ── Lista de intervenciones ─────────────────────────────────
  List<dynamic> interventions = [];
  bool isLoading = true;
  String errorMessage = '';

  // Filtros
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  final List<Map<String, dynamic>> _statusOptions = [
    {'value': null, 'label': 'Todos', 'color': Colors.grey},
    {'value': '0', 'label': 'Borrador', 'color': Colors.grey},
    {'value': '1', 'label': 'En Curso', 'color': Colors.blue},
    {'value': '2', 'label': 'Facturadas', 'color': Colors.orange},
    {'value': '3', 'label': 'Terminada', 'color': Colors.green},
  ];

  final List<Map<String, dynamic>> _refClientOptions = [
    {'value': null, 'label': 'Todos'},
    {'value': 'SRVT', 'label': 'SRVT'},
    {'value': 'SRVD', 'label': 'SRVD'},
    {'value': 'SRVI', 'label': 'SRVI'},
    {'value': 'SRVR', 'label': 'SRVR'},
  ];

  String? _selectedRefClient; // Variable de estado

  @override
  void initState() {
    super.initState();
    _loadInterventions();

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabRotation = Tween<double>(begin: 0.0, end: 0.375).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
    _fabScale = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _fabExpanded = !_fabExpanded;
      if (_fabExpanded) {
        _fabAnimController.forward();
      } else {
        _fabAnimController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() {
        _fabExpanded = false;
        _fabAnimController.reverse();
      });
    }
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
        refClientfilter: _selectedRefClient
      );

      // Enriquecer con nombre real del cliente en paralelo
      await Future.wait(
        loaded.map((intervention) async {
          // Si ya viene el nombre no hacemos nada
          if (intervention['thirdparty_name'] != null &&
              intervention['thirdparty_name'].toString().isNotEmpty)
            return;

          final socid = intervention['socid']?.toString();
          if (socid == null || socid.isEmpty || socid == '0') return;

          try {
            final response = await http.get(
              Uri.parse('${AppConstants.baseUrl}/thirdparties/$socid'),
              headers: {
                'DOLAPIKEY': widget.token,
                'Accept': 'application/json',
              },
            );
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              intervention['thirdparty_name'] = data['name'] ?? 'Sin nombre';
            }
          } catch (_) {}
        }),
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

  // ── Helpers de estado ───────────────────────────────────────
  Color _getStatusColor(String? s) {
    switch (s) {
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

  String _getStatusLabel(String? s) {
    switch (s) {
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

  IconData _getStatusIcon(String? s) {
    switch (s) {
      case '0':
        return Icons.edit_note;
      case '1':
        return Icons.pending_actions;
      case '2':
        return Icons.receipt_long;
      case '3':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  /// Formato "01 Abr 2026"
  String _formatDate(dynamic timestamp) {
    if (timestamp == null || timestamp == '') return 'Sin Fecha';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp.toString()) * 1000,
      );
      const months = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      return '$day $month ${date.year}';
    } catch (_) {
      return 'Sin Fecha';
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

  // ── Mini-FAB de cada opción del Speed Dial ───────────────────
  Widget _buildFabOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    return ScaleTransition(
      scale: _fabScale,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Etiqueta flotante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Mini FAB
            FloatingActionButton.small(
              heroTag: 'fab_int_option_$index',
              backgroundColor: color,
              onPressed: () {
                _closeFab();
                onTap();
              },
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header con buscador + filtros ─────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                color: Colors.white,
                child: Column(
                  children: [
                    // Buscador
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por referencia o descripción...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.blue,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadInterventions();
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
                      onSubmitted: (_) => _loadInterventions(),
                      textInputAction: TextInputAction.search,
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
                                color: isSelected
                                    ? color
                                    : Colors.grey.shade300,
                              ),
                              onSelected: (_) {
                                setState(
                                  () => _selectedStatus = option['value'],
                                );
                                _loadInterventions();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _refClientOptions.length,
                        itemBuilder: (context, index) {
                          final option = _refClientOptions[index];
                          final isSelected =
                              _selectedRefClient == option['value'];

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(option['label']),
                              selectedColor: const Color(
                                0xFF1565C0,
                              ).withOpacity(0.15),
                              checkmarkColor: const Color(0xFF1565C0),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey[700],
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF1565C0)
                                    : Colors.grey.shade300,
                              ),
                              onSelected: (_) {
                                setState(
                                  () => _selectedRefClient = option['value'],
                                );
                                _loadInterventions();
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
              if (!isLoading && errorMessage.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${interventions.length} intervención(es) encontrada(s)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
                ),

              // ── Lista ─────────────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1565C0),
                        ),
                      )
                    : errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error,
                              size: 64,
                              color: Colors.red,
                            ),
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
                            Icon(
                              Icons.inbox,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay intervenciones',
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
                                    _selectedRefClient = null;
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
                          padding: const EdgeInsets.all(12),
                          itemCount: interventions.length,
                          itemBuilder: (context, index) {
                            final intervention = interventions[index];
                            final status = intervention['statut']?.toString();
                            final color = _getStatusColor(status);

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
                                  _closeFab();
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
                                  _loadInterventions();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Fila superior
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _getStatusIcon(status),
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
                                                  intervention['ref'] ?? 'N/A',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  intervention['description'] ??
                                                      'Sin descripción',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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

                                      // Fila badges
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: color.withOpacity(0.4),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusLabel(status),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),

                                          const SizedBox(width: 8),

                                          // Cliente badge
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.business,
                                                  size: 12,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    _getClientName(
                                                      intervention,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 6),

                                      // Fila fechas
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 12,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDate(intervention['datec']),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),

                                          // Proyecto si existe
                                          if (intervention['fk_project'] !=
                                                  null &&
                                              intervention['fk_project']
                                                      .toString() !=
                                                  '0' &&
                                              intervention['fk_project']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.folder_open,
                                              size: 12,
                                              color: const Color(
                                                0xFF1565C0,
                                              ).withOpacity(0.7),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                intervention['project_ref'] ??
                                                    'ID ${intervention['fk_project']}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF1565C0),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
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
        ),

        // ── FAB único con Speed Dial ────────────────────────────
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Opciones (visibles sólo cuando está expandido)
            if (_fabExpanded) ...[
              _buildFabOption(
                label: 'Pendientes',
                icon: Icons.track_changes,
                color: const Color(0xFF6A1B9A),
                index: 0,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SeguimientoScreen(token: widget.token),
                    ),
                  );
                },
              ),
              _buildFabOption(
                label: 'Nueva Intervención',
                icon: Icons.build_circle,
                color: const Color(0xFF1565C0),
                index: 1,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateInterventionScreen(token: widget.token),
                    ),
                  );
                  _loadInterventions();
                },
              ),
            ],

            // FAB principal — rota al expandirse
            RotationTransition(
              turns: _fabRotation,
              child: FloatingActionButton(
                heroTag: 'fab_int_main',
                onPressed: _toggleFab,
                backgroundColor: _fabExpanded
                    ? Colors.grey[700]
                    : const Color(0xFF1565C0),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
