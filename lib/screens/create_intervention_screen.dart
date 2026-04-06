import 'package:flutter/material.dart';
import '../services/dolibarr_service.dart';
import 'interventions_list_screen.dart';
import '../services/project_service.dart';

class CreateInterventionScreen extends StatefulWidget {
  final String token;

  const CreateInterventionScreen({super.key, required this.token});

  @override
  State<CreateInterventionScreen> createState() =>
      _CreateInterventionScreenState();
}

class _CreateInterventionScreenState extends State<CreateInterventionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refClientController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notePublicController = TextEditingController();
  final _notePrivateController = TextEditingController();
  final _clientSearchController = TextEditingController();
  List<dynamic> _filteredClients = [];
  String? _selectedClientName;

  List<dynamic> _projects = [];
  List<dynamic> _filteredProjects = [];
  String? _selectedProjectId;
  String? _selectedProjectName;
  bool _loadingProjects = false;
  final _projectSearchController = TextEditingController();

  List<dynamic> _clients = [];
  String? _selectedClientId;
  bool _loadingClients = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _loadProjects();
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
      print('Error cargando clientes: $e');
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _loadingProjects = true);
    try {
      final projects = await ProjectService.getProjects(widget.token);
      setState(() {
        _projects = projects;
        _filteredProjects = projects;
        _loadingProjects = false;
      });
    } catch (e) {
      setState(() => _loadingProjects = false);
    }
  }

  void _filterProjects(String query) {
    setState(() {
      _filteredProjects = query.isEmpty
          ? _projects
          : _projects.where((p) {
              final ref = (p['ref'] ?? '').toString().toLowerCase();
              final title = (p['title'] ?? '').toString().toLowerCase();
              return ref.contains(query.toLowerCase()) ||
                  title.contains(query.toLowerCase());
            }).toList();
    });
  }

  Future<void> _createIntervention() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final result = await DolibarrService.createIntervention(
        token: widget.token,
        thirdpartyId: _selectedClientId!,
        refClient: _refClientController.text.isNotEmpty
            ? _refClientController.text
            : null,
        description: _descriptionController.text,
        notePublic: _notePublicController.text.isNotEmpty
            ? _notePublicController.text
            : null,
        notePrivate: _notePrivateController.text.isNotEmpty
            ? _notePrivateController.text
            : null,
        fkProject: _selectedProjectId,
      );

      setState(() => _isCreating = false);

      if (!mounted) return;

      if (result['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Intervención creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        // Ir a la lista de intervenciones
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InterventionsListScreen(token: widget.token),
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
    } catch (e) {
      setState(() => _isCreating = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _refClientController.dispose();
    _descriptionController.dispose();
    _notePublicController.dispose();
    _clientSearchController.dispose();
    _projectSearchController.dispose();
    super.dispose();
    _notePrivateController.dispose();
    super.dispose();
  }

  void _filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        _filteredClients = _clients.where((client) {
          final name = (client['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Intervención'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Icono
            const Icon(Icons.build_circle, size: 80, color: Colors.blue),
            const SizedBox(height: 16),

            const Text(
              'Nueva Intervención',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              'Crear borrador de intervención',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Cliente (Tercero) - OBLIGATORIO
            const Text(
              'Cliente (Tercero) *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            _loadingClients
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Buscador
                      TextField(
                        controller: _clientSearchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar cliente...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.blue[300],
                          ),
                          suffixIcon: _clientSearchController.text.isNotEmpty
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
                          filled: true,
                          fillColor: const Color(0xFFF0F6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1565C0),
                              width: 1.5,
                            ),
                          ),
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

                      // Lista de resultados
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

            const SizedBox(height: 20),

            // ✅ Sección de proyecto opcional
            const Text(
              'Vincular a Proyecto (opcional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Si esta intervención pertenece a un proyecto',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),

            _loadingProjects
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Buscador
                      TextField(
                        controller: _projectSearchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar proyecto...',
                          prefixIcon: Icon(
                            Icons.folder_open,
                            color: Colors.blue[300],
                          ),
                          suffixIcon: _projectSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _projectSearchController.clear();
                                    _filterProjects('');
                                    setState(() {
                                      _selectedProjectId = null;
                                      _selectedProjectName = null;
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF0F6FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1565C0),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: _filterProjects,
                      ),

                      // Proyecto seleccionado
                      if (_selectedProjectId != null)
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
                                Icons.folder,
                                color: Colors.blue,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedProjectName ?? '',
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
                                    _selectedProjectId = null;
                                    _selectedProjectName = null;
                                    _projectSearchController.clear();
                                    _filteredProjects = _projects;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                      // Lista resultados
                      if (_projectSearchController.text.isNotEmpty &&
                          _selectedProjectId == null)
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
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: _filteredProjects.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No se encontraron proyectos',
                                    style: TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _filteredProjects.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final project = _filteredProjects[index];
                                    final title =
                                        project['title'] ?? 'Sin título';
                                    final ref = project['ref'] ?? '';
                                    return ListTile(
                                      dense: true,
                                      leading: const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Color(0xFFF0F6FF),
                                        child: Icon(
                                          Icons.folder_open,
                                          color: Color(0xFF1565C0),
                                          size: 16,
                                        ),
                                      ),
                                      title: Text(
                                        title,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        ref,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedProjectId = project['id']
                                              .toString();
                                          _selectedProjectName =
                                              '$ref - $title';
                                          _projectSearchController.clear();
                                          _filteredProjects = _projects;
                                        });
                                        FocusScope.of(context).unfocus();
                                      },
                                    );
                                  },
                                ),
                        ),
                    ],
                  ),
            const SizedBox(height: 20),

            // Ref. Cliente (Opcional)
            const Text(
              'Ref. Cliente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _refClientController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: REF-2026-001',
                prefixIcon: Icon(Icons.tag),
              ),
            ),

            const SizedBox(height: 20),

            // Descripción - OBLIGATORIA
            const Text(
              'Descripción *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Descripción general de la intervención',
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La descripción es obligatoria';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Nota Pública (para el cliente)
            const Text(
              'Nota Pública (para el cliente)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notePublicController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Visible para el cliente',
                prefixIcon: const Icon(Icons.visibility),
                filled: true,
                fillColor: Colors.green.shade50,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 20),

            // Nota Privada (interna)
            const Text(
              'Nota Privada (interna)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notePrivateController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Solo visible internamente',
                prefixIcon: const Icon(Icons.lock),
                filled: true,
                fillColor: Colors.orange.shade50,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Botón Crear Borrador
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createIntervention,
                icon: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isCreating ? 'Creando...' : 'Crear Borrador',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botón Cancelar
            OutlinedButton.icon(
              onPressed: _isCreating
                  ? null
                  : () {
                      _refClientController.clear();
                      _descriptionController.clear();
                      _notePublicController.clear();
                      _notePrivateController.clear();
                      _clientSearchController.clear();
                      setState(() {
                        _selectedClientId = null;
                        _selectedClientName = null;
                        _filteredClients = _clients;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Formulario limpiado')),
                      );
                    },
              icon: const Icon(Icons.cancel),
              label: const Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
