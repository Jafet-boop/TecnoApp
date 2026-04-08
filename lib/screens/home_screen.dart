import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'create_intervention_screen.dart';
import 'interventions_list_screen.dart';
import '../services/session_service.dart';
import '../services/dolibarr_service.dart';
import 'projects_list_screen.dart';
import '../services/project_service.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardTab(userData: widget.userData),
      ProjectsListScreen(
        token: widget.userData['token'],
        userData: widget.userData,
      ),
      InterventionsListScreen(token: widget.userData['token']),
      CreateInterventionScreen(token: widget.userData['token']),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final String userName = widget.userData['login'] ?? 'Usuario';
    final String firstName = widget.userData['firstname'] ?? '';
    final String lastName = widget.userData['lastname'] ?? '';
    final String fullName = firstName.isNotEmpty && lastName.isNotEmpty
        ? '$firstName $lastName'
        : userName;
    final bool isAdmin = widget.userData['admin'] == '1';

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/tecnologo.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1565C0),
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: const Color(0xFF1565C0),
              radius: 16,
              child: Text(
                _getInitials(fullName),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(userData: widget.userData),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1565C0), Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _getInitials(fullName),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
              accountName: Text(
                fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              accountEmail: Text('@$userName'),
              otherAccountsPictures: [
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF1565C0)),
              title: const Text('Mi Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen(userData: widget.userData),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Configuración'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente...')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Proyectos'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Intervenciones',),
        ],
      ),
    );
  }

String _getInitials(String name) {
  // 1. Limpiamos espacios y verificamos si está vacío de una vez
  String cleanName = name.trim();
  if (cleanName.isEmpty) {
    return 'U'; // 'U' de Usuario o lo que prefieras
  }
  List<String> parts = cleanName.split(' ');
  // 2. Si tiene nombre y apellido (ej. "Juan Pérez")
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  // 3. Si solo tiene un nombre (ej. "Juan")
  if (parts[0].isNotEmpty) {
    return parts[0][0].toUpperCase();
  }
  return 'U';
}

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar Sesión'),
          ],
        ),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              Navigator.pop(context);
              await SessionService.clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Tab ─────────────────────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  const _DashboardTab({required this.userData});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  List<dynamic> _interventions = [];
  List<dynamic> _projects = [];
  bool _isLoading = true;

  // Intervenciones
  int get _borrador =>
      _interventions.where((i) => i['statut']?.toString() == '0').length;
  int get _validadas =>
      _interventions.where((i) => i['statut']?.toString() == '1').length;
  int get _enProceso =>
      _interventions.where((i) => i['statut']?.toString() == '2').length;
  int get _terminadas =>
      _interventions.where((i) => i['statut']?.toString() == '3').length;
  int get _total => _interventions.length;

  // Proyectos
  int get _proyBorrador =>
      _projects.where((p) => p['status']?.toString() == '0').length;
  int get _proyAbiertos =>
      _projects.where((p) => p['status']?.toString() == '1').length;
  int get _proyCerrados =>
      _projects.where((p) => p['status']?.toString() == '2').length;
  int get _totalProyectos => _projects.length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      DolibarrService.getInterventions(widget.userData['token']),
      ProjectService.getProjects(widget.userData['token']),
    ]);

    setState(() {
      _interventions = results[0] as List<dynamic>;
      _projects = results[1] as List<dynamic>;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String firstName =
        widget.userData['firstname'] ?? widget.userData['login'] ?? 'Usuario';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Saludo ──────────────────────────────────────────
            Text(
              '¡Hola, $firstName!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            Text(
              'Aquí está el resumen de hoy',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                ),
              )
            else ...[
              // ── Sección Intervenciones ───────────────────────
              _buildSectionTitle(
                'Intervenciones',
                Icons.confirmation_number,
                'Total: $_total',
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _StatCard(
                    label: 'Total',
                    value: _total,
                    color: const Color(0xFF1565C0),
                    icon: Icons.confirmation_number,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Borrador',
                    value: _borrador,
                    color: Colors.grey,
                    icon: Icons.edit,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    label: 'Validadas',
                    value: _validadas,
                    color: Colors.blue,
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Facturadas',
                    value: _enProceso,
                    color: Colors.orange,
                    icon: Icons.build,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    label: 'Terminadas',
                    value: _terminadas,
                    color: Colors.green,
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Container()),
                ],
              ),

              const SizedBox(height: 24),

              // ── Gráfica intervenciones ───────────────────────
              if (_total > 0) ...[
                const Text(
                  'Distribución de Intervenciones',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildPieChart(
                  sections: [
                    if (_borrador > 0) _pieSection(_borrador, Colors.grey),
                    if (_validadas > 0) _pieSection(_validadas, Colors.blue),
                    if (_enProceso > 0) _pieSection(_enProceso, Colors.orange),
                    if (_terminadas > 0) _pieSection(_terminadas, Colors.green),
                  ],
                  legends: [
                    _LegendItem(
                      color: Colors.grey,
                      label: 'Borrador',
                      value: _borrador,
                    ),
                    _LegendItem(
                      color: Colors.blue,
                      label: 'Validadas',
                      value: _validadas,
                    ),
                    _LegendItem(
                      color: Colors.orange,
                      label: 'Facturadas',
                      value: _enProceso,
                    ),
                    _LegendItem(
                      color: Colors.green,
                      label: 'Terminadas',
                      value: _terminadas,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // ── Sección Proyectos ────────────────────────────
              _buildSectionTitle(
                'Proyectos',
                Icons.folder,
                'Total: $_totalProyectos',
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _StatCard(
                    label: 'Total',
                    value: _totalProyectos,
                    color: const Color(0xFF1565C0),
                    icon: Icons.folder,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Borrador',
                    value: _proyBorrador,
                    color: Colors.grey,
                    icon: Icons.edit,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    label: 'Abiertos',
                    value: _proyAbiertos,
                    color: Colors.green,
                    icon: Icons.folder_open,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Cerrados',
                    value: _proyCerrados,
                    color: Colors.red,
                    icon: Icons.folder,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Gráfica proyectos ────────────────────────────
              if (_totalProyectos > 0) ...[
                const Text(
                  'Distribución de Proyectos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildPieChart(
                  sections: [
                    if (_proyBorrador > 0)
                      _pieSection(_proyBorrador, Colors.grey),
                    if (_proyAbiertos > 0)
                      _pieSection(_proyAbiertos, Colors.green),
                    if (_proyCerrados > 0)
                      _pieSection(_proyCerrados, Colors.red),
                  ],
                  legends: [
                    _LegendItem(
                      color: Colors.grey,
                      label: 'Borrador',
                      value: _proyBorrador,
                    ),
                    _LegendItem(
                      color: Colors.green,
                      label: 'Abiertos',
                      value: _proyAbiertos,
                    ),
                    _LegendItem(
                      color: Colors.red,
                      label: 'Cerrados',
                      value: _proyCerrados,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // ── Últimas intervenciones ───────────────────────
              _buildSectionTitle('Últimas Intervenciones', Icons.history, ''),
              const SizedBox(height: 10),

              if (_interventions.isEmpty)
                _buildEmptyState('Sin intervenciones', Icons.inbox)
              else
                ..._interventions.take(5).map((intervention) {
                  final status = intervention['statut']?.toString();
                  final color = _statusColor(status);
                  final ref = intervention['ref'] ?? 'N/A';
                  final desc = intervention['description'] ?? 'Sin descripción';
                  final date = _formatDate(intervention['datec']);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(
                          _statusIcon(status),
                          color: color,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            ref,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        date,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 20),

              // ── Últimos proyectos ────────────────────────────
              _buildSectionTitle('Últimos Proyectos', Icons.folder_open, ''),
              const SizedBox(height: 10),

              if (_projects.isEmpty)
                _buildEmptyState('Sin proyectos', Icons.folder_open)
              else
                ..._projects.take(5).map((project) {
                  final status = project['status']?.toString();
                  final color = _proyStatusColor(status);
                  final ref = project['ref'] ?? 'N/A';
                  final title = project['title'] ?? 'Sin título';
                  final date = _formatDate(project['date_start']);
                  final isPublic = project['public']?.toString() == '1';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(
                          isPublic ? Icons.folder_open : Icons.lock,
                          color: color,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            ref,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _proyStatusLabel(status),
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        date,
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ),
                  );
                }).toList(),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1565C0), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
      ],
    );
  }

  Widget _buildPieChart({
    required List<PieChartSectionData> sections,
    required List<Widget> legends,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 160,
            width: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 45,
                sections: sections,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: legends,
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(int value, Color color) {
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      radius: 35,
      title: '$value',
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(String label, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  Color _statusColor(String? s) {
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

  String _statusLabel(String? s) {
    switch (s) {
      case '0':
        return 'Borrador';
      case '1':
        return 'Validada';
      case '2':
        return 'Facturadas';
      case '3':
        return 'Terminada';
      default:
        return 'Desconocido';
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
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

  Color _proyStatusColor(String? s) {
    switch (s) {
      case '0':
        return Colors.grey;
      case '1':
        return Colors.green;
      case '2':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _proyStatusLabel(String? s) {
    switch (s) {
      case '0':
        return 'Borrador';
      case '1':
        return 'Abierto';
      case '2':
        return 'Cerrado';
      default:
        return 'Desconocido';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(
        int.parse(timestamp.toString()) * 1000,
      );
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}

// ── Proyectos Tab ─────────────────────────────────────────────────────────────
class _ProyectosTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Proyectos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text('Próximamente...', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
