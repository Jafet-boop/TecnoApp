import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../services/dolibarr_service.dart';
import 'projects_list_screen.dart';

class CreateProjectScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> userData;

  const CreateProjectScreen({
    super.key,
    required this.token,
    required this.userData,
  });

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _clientSearchController = TextEditingController();

  // Clientes
  List<dynamic> _clients = [];
  List<dynamic> _filteredClients = [];
  String? _selectedClientId;
  String? _selectedClientName;
  bool _loadingClients = false;

  // Fechas
  DateTime _dateStart = DateTime.now();
  DateTime _dateEnd = DateTime.now().add(const Duration(days: 30));

  // Opciones
  String _status = '1'; // Abierto por defecto
  String _isPublic = '1'; // Público por defecto
  String _oppStatus = '1'; // Nuevo status

  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _refController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _clientSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() => _loadingClients = true);
    try {
      final clients = await DolibarrService.getThirdparties(widget.token);
      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _loadingClients = false;
      });
    } catch (e) {
      setState(() => _loadingClients = false);
    }
  }

  void _filterClients(String query) {
    setState(() {
      _filteredClients = query.isEmpty
          ? _clients
          : _clients.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              return name.contains(query.toLowerCase());
            }).toList();
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _dateStart : _dateEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _dateStart = picked;
          if (_dateEnd.isBefore(_dateStart)) {
            _dateEnd = _dateStart.add(const Duration(days: 1));
          }
        } else {
          _dateEnd = picked;
        }
      });
    }
  }

  Future<void> _createProject() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_dateEnd.isBefore(_dateStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha de fin no puede ser antes de la de inicio'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final result = await ProjectService.createProject(
      token: widget.token,
      ref: _refController.text.trim(),
      title: _titleController.text.trim(),
      socid: _selectedClientId!,
      dateStart: _dateStart.millisecondsSinceEpoch ~/ 1000,
      dateEnd: _dateEnd.millisecondsSinceEpoch ~/ 1000,
      description: _descriptionController.text.trim(),
      status: _status,
      isPublic: _isPublic,
      oppStatus:   _oppStatus,
    );

    setState(() => _isCreating = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proyecto creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectsListScreen(
            token: widget.token,
            userData: widget.userData,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Nuevo Proyecto'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Referencia ──────────────────────────────────────
            _buildLabel('Referencia *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _refController,
              decoration: _inputDecoration(
                hint: 'Ej: PJ-2026-0001',
                icon: Icons.tag,
              ),
              validator: (v) => v == null || v.isEmpty
                  ? 'La referencia es obligatoria'
                  : null,
            ),

            const SizedBox(height: 16),

            // ── Título ──────────────────────────────────────────
            _buildLabel('Título *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(
                hint: 'Título del proyecto',
                icon: Icons.title,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'El título es obligatorio' : null,
            ),

            const SizedBox(height: 16),

            // ── Cliente ─────────────────────────────────────────
            _buildLabel('Cliente *'),
            const SizedBox(height: 6),
            _loadingClients
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Buscador
                      TextField(
                        controller: _clientSearchController,
                        decoration:
                            _inputDecoration(
                              hint: 'Buscar cliente...',
                              icon: Icons.search,
                            ).copyWith(
                              suffixIcon:
                                  _clientSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        _clientSearchController.clear();
                                        _filterClients('');
                                        setState(() {
                                          _selectedClientId = null;
                                          _selectedClientName = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                        onChanged: _filterClients,
                      ),

                      // Cliente seleccionado
                      if (_selectedClientId != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedClientName ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _selectedClientId = null;
                                    _selectedClientName = null;
                                    _clientSearchController.clear();
                                    _filteredClients = _clients;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                      // Lista resultados
                      if (_clientSearchController.text.isNotEmpty &&
                          _selectedClientId == null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: _filteredClients.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No se encontraron clientes',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _filteredClients.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final client = _filteredClients[index];
                                    final name = client['name'] ?? 'Sin nombre';
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: const Color(
                                          0xFFF0F6FF,
                                        ),
                                        child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            color: Color(0xFF1565C0),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedClientId = client['id']
                                              .toString();
                                          _selectedClientName = name;
                                          _clientSearchController.clear();
                                          _filteredClients = _clients;
                                        });
                                        FocusScope.of(context).unfocus();
                                      },
                                    );
                                  },
                                ),
                        ),
                    ],
                  ),

            const SizedBox(height: 16),

            // ── Fechas ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Fecha Inicio *'),
                      const SizedBox(height: 6),
                      _buildDateTile(
                        date: _dateStart,
                        onTap: () => _pickDate(true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Fecha Fin *'),
                      const SizedBox(height: 6),
                      _buildDateTile(
                        date: _dateEnd,
                        onTap: () => _pickDate(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Descripción ─────────────────────────────────────
            _buildLabel('Descripción'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(
                hint: 'Descripción del proyecto...',
                icon: Icons.description,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // ── Status ──────────────────────────────────────────
            // ── Estado del Proyecto ─────────────────────────────
            _buildLabel('Estado del Proyecto'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '0', child: Text('Borrador')),
                    DropdownMenuItem(value: '1', child: Text('Abierto')),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Etapa Comercial (opp_status) ────────────────────
            _buildLabel('Etapa Comercial'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _oppStatus,
                  isExpanded: true,
                  items: [
                    _oppItem('1', 'Prospecto', Colors.purple),
                    _oppItem('2', 'Por Cotizar', Colors.orange),
                    _oppItem('3', 'Seguimiento', Colors.blue),
                    _oppItem('4', 'Por Atender', Colors.cyan),
                    _oppItem('5', 'En Proceso', Colors.indigo),
                    _oppItem('6', 'Por Cobrar', Colors.teal),
                    _oppItem('7', 'Postventa', Colors.green),
                  ],
                  onChanged: (v) => setState(() => _oppStatus = v!),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Visibilidad ─────────────────────────────────────
            _buildLabel('Visibilidad'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    label: 'Público',
                    icon: Icons.public,
                    color: Colors.blue,
                    selected: _isPublic == '1',
                    onTap: () => setState(() => _isPublic = '1'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionCard(
                    label: 'Privado',
                    icon: Icons.lock,
                    color: Colors.orange,
                    selected: _isPublic == '0',
                    onTap: () => setState(() => _isPublic = '0'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ── Botón Crear ─────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createProject,
                icon: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isCreating ? 'Creando...' : 'Crear Proyecto',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Botón Cancelar ──────────────────────────────────
            OutlinedButton.icon(
              onPressed: _isCreating ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  DropdownMenuItem<String> _oppItem(String value, String label, Color color) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: Colors.blue[300]),
      filled: true,
      fillColor: const Color(0xFFF0F6FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildDateTile({required DateTime date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.blue[300]),
            const SizedBox(width: 8),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : const Color(0xFFF0F6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
