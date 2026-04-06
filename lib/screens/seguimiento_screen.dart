import 'package:flutter/material.dart';
import 'intervention_detail_screen.dart';
import '../services/dolibarr_service.dart';
import '../services/session_service.dart';

class SeguimientoScreen extends StatefulWidget {
  final String token;

  const SeguimientoScreen({super.key, required this.token});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  // ── Estado general ──────────────────────────────────────────
  bool _isLoading = true;
  String _errorMessage = '';

  // ── Usuario logueado ────────────────────────────────────────
  String? _loggedUserId;
  String _loggedUserName = '';

  // ── Modo "ver todos" (toggle opcional) ─────────────────────
  bool _showingAll = false;

  // ── Técnicos disponibles (para modo "ver todos") ────────────
  List<Map<String, dynamic>> _technicians = [];
  Map<String, dynamic>? _selectedTechnician;

  // ── Intervenciones ──────────────────────────────────────────
  List<Map<String, dynamic>> _allPendingInterventions = [];
  List<Map<String, dynamic>> _filteredInterventions = [];

  // ── Búsqueda ────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── 1. Leer sesión y luego cargar datos ─────────────────────
  Future<void> _initAndLoad() async {
    final session = await SessionService.getSavedSession();
    if (session != null) {
      final id = session['id']?.toString() ?? session['rowid']?.toString();
      final firstName = session['firstname'] ?? '';
      final lastName = session['lastname'] ?? '';
      final fullName = '$firstName $lastName'.trim();

      setState(() {
        _loggedUserId = id;
        _loggedUserName = fullName.isNotEmpty
            ? fullName
            : session['login'] ?? 'Mi cuenta';
      });
    }

    await _loadData();
  }

  // ── 2. Carga paralela de intervenciones ─────────────────────
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Traer las intervenciones pendientes
      final results = await Future.wait([
        DolibarrService.getInterventions(widget.token, statusFilter: '0'),
        DolibarrService.getInterventions(widget.token, statusFilter: '1'),
      ]);

      final combinedRaw = [
        ...results[0].cast<Map<String, dynamic>>(),
        ...results[1].cast<Map<String, dynamic>>(),
      ];

      // Cargar detalles completos EN PARALELO (todos a la vez)
      final fullList = await Future.wait(
        combinedRaw.map((intervention) async {
          final full = await DolibarrService.getInterventionById(
            token: widget.token,
            interventionId: intervention['id'].toString(),
          );
          return full ?? intervention;
        }),
      );

      // Recopilar IDs únicos de técnicos internos
      final Set<String> allTechIds = {};
      for (final intervention in fullList) {
        final internalIds =
            intervention['contacts_ids_internal'] as List<dynamic>? ?? [];
        for (final id in internalIds) {
          allTechIds.add(id.toString());
        }
      }

      // Cargar usuarios EN PARALELO
      final Map<String, Map<String, dynamic>> technicianMap = {};
      await Future.wait(
        allTechIds.map((idStr) async {
          final user = await DolibarrService.getUserById(
            token: widget.token,
            userId: idStr,
          );
          if (user != null) technicianMap[idStr] = user;
        }),
      );

      setState(() {
        _allPendingInterventions = fullList.cast<Map<String, dynamic>>();
        _technicians = technicianMap.values.toList();
        _isLoading = false;
      });

      _applyFilter();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  // ── 3. Filtro: usuario logueado O técnico seleccionado ───────
  void _applyFilter() {
    List<Map<String, dynamic>> result = List.from(_allPendingInterventions);

    if (_showingAll) {
      // Modo "ver todos": filtrar por técnico seleccionado en dropdown
      if (_selectedTechnician != null) {
        final selectedId = _selectedTechnician!['id'].toString();
        result = result.where((i) {
          final ids = i['contacts_ids_internal'] as List<dynamic>? ?? [];
          return ids.any((id) => id.toString() == selectedId);
        }).toList();
      }
    } else {
      // Modo normal: solo mis intervenciones (usuario logueado)
      if (_loggedUserId != null) {
        result = result.where((i) {
          final ids = i['contacts_ids_internal'] as List<dynamic>? ?? [];
          return ids.any((id) => id.toString() == _loggedUserId);
        }).toList();
      }
    }

    // Filtro de texto
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((i) {
        final ref = (i['ref'] ?? '').toString().toLowerCase();
        final desc = (i['description'] ?? '').toString().toLowerCase();
        return ref.contains(query) || desc.contains(query);
      }).toList();
    }

    setState(() => _filteredInterventions = result);
  }

  // ── Helpers ──────────────────────────────────────────────────
  Color _getStatusColor(String? status) {
    switch (status) {
      case '0':
        return const Color(0xFF78909C);
      case '1':
        return const Color.fromARGB(255, 0, 184, 230);
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
      default:
        return 'Desconocido';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case '0':
        return Icons.edit_note;
      case '1':
        return Icons.build_circle;
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
    } catch (_) {
      return 'N/A';
    }
  }

  String _getTechName(Map<String, dynamic> user) {
    final first = user['firstname'] ?? '';
    final last = user['lastname'] ?? '';
    final full = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Sin nombre';
  }

  String _getTechInitials(Map<String, dynamic> user) {
    final f = (user['firstname'] ?? '').toString();
    final l = (user['lastname'] ?? '').toString();
    return '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'
        .toUpperCase();
  }

  int _countByStatus(String status) => _filteredInterventions
      .where((i) => i['statut']?.toString() == status)
      .length;

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Seguimiento'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Toggle: mis pendientes ↔ ver todos
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showingAll = !_showingAll;
                _selectedTechnician = null;
              });
              _applyFilter();
            },
            icon: Icon(
              _showingAll ? Icons.person : Icons.people,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              _showingAll ? 'Mis pendientes' : 'Ver todos',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _errorMessage.isNotEmpty
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Cargando intervenciones pendientes…',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        if (_showingAll) _buildTechnicianDropdown(),
        _buildSearchBar(),
        _buildSummaryBadges(),
        _buildList(),
      ],
    );
  }

  // ── Header con nombre del técnico activo ─────────────────────
  Widget _buildHeader() {
    final title = _showingAll
        ? (_selectedTechnician != null
            ? _getTechName(_selectedTechnician!)
            : 'Todos los técnicos')
        : _loggedUserName.isNotEmpty
            ? _loggedUserName
            : 'Mis pendientes';

    return Container(
      width: double.infinity,
      color: Colors.blue,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_filteredInterventions.length} intervención(es) pendiente(s)',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Dropdown de técnicos (solo en modo "ver todos") ──────────
  Widget _buildTechnicianDropdown() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.engineering, color: Colors.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>?>(
                isExpanded: true,
                value: _selectedTechnician,
                hint: const Text('Filtrar por técnico'),
                items: [
                  const DropdownMenuItem<Map<String, dynamic>?>(
                    value: null,
                    child: Text('Todos los técnicos'),
                  ),
                  ..._technicians.map((tech) {
                    return DropdownMenuItem<Map<String, dynamic>?>(
                      value: tech,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              _getTechInitials(tech),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(_getTechName(tech)),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _selectedTechnician = value);
                  _applyFilter();
                },
              ),
            ),
          ),
          if (_selectedTechnician != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () {
                setState(() => _selectedTechnician = null);
                _applyFilter();
              },
            ),
        ],
      ),
    );
  }

  // ── Buscador ─────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por referencia o descripción…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: (_) => _applyFilter(),
      ),
    );
  }

  // ── Badges resumen ───────────────────────────────────────────
  Widget _buildSummaryBadges() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildBadge(
            label: 'Borrador',
            count: _countByStatus('0'),
            color: _getStatusColor('0'),
            icon: Icons.edit_note,
          ),
          const SizedBox(width: 10),
          _buildBadge(
            label: 'En Curso',
            count: _countByStatus('1'),
            color: _getStatusColor('1'),
            icon: Icons.build_circle,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista ────────────────────────────────────────────────────
  Widget _buildList() {
    if (_filteredInterventions.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 72, color: Colors.green.shade300),
              const SizedBox(height: 16),
              Text(
                _showingAll
                    ? 'No hay intervenciones pendientes'
                    : '¡Sin pendientes por ahora! 🎉',
                style: TextStyle(fontSize: 17, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              if (_searchController.text.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _applyFilter();
                  },
                  child: const Text('Limpiar búsqueda'),
                ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          itemCount: _filteredInterventions.length,
          itemBuilder: (context, index) =>
              _buildCard(_filteredInterventions[index]),
        ),
      ),
    );
  }

  // ── Tarjeta de intervención ──────────────────────────────────
  Widget _buildCard(Map<String, dynamic> intervention) {
    final status = intervention['statut']?.toString();
    final statusColor = _getStatusColor(status);
    final internalIds =
        intervention['contacts_ids_internal'] as List<dynamic>? ?? [];

    final assignedNames = _technicians
        .where((t) =>
            internalIds.any((id) => id.toString() == t['id'].toString()))
        .map((t) => _getTechName(t))
        .join(', ');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InterventionDetailScreen(
                intervention: intervention,
                token: widget.token,
              ),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ref + badge status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    intervention['ref'] ?? 'Sin ref',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(status),
                            size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          _getStatusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Descripción
              Text(
                intervention['description'] ?? 'Sin descripción',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Cliente + fecha
              Row(
                children: [
                  const Icon(Icons.business, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      intervention['thirdparty_name'] ??
                          'ID: ${intervention['socid'] ?? 'N/A'}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.calendar_today,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(intervention['datec']),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

              // Técnicos (solo en modo "ver todos")
              if (_showingAll) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      assignedNames.isNotEmpty
                          ? Icons.engineering
                          : Icons.warning_amber,
                      size: 13,
                      color: assignedNames.isNotEmpty
                          ? Colors.blue
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assignedNames.isNotEmpty
                            ? assignedNames
                            : 'Sin técnico asignado',
                        style: TextStyle(
                          fontSize: 12,
                          color: assignedNames.isNotEmpty
                              ? Colors.blue
                              : Colors.orange.shade700,
                          fontWeight: assignedNames.isNotEmpty
                              ? FontWeight.w500
                              : FontWeight.normal,
                          fontStyle: assignedNames.isNotEmpty
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}