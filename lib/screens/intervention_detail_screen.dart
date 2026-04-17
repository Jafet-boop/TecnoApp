import 'dart:convert';
import 'package:app_tecno/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../services/dolibarr_service.dart';

class InterventionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> intervention;
  final String token;

  const InterventionDetailScreen({
    super.key,
    required this.intervention,
    required this.token,
  });

  @override
  State<InterventionDetailScreen> createState() =>
      _InterventionDetailScreenState();
}

class _InterventionDetailScreenState extends State<InterventionDetailScreen>
    with SingleTickerProviderStateMixin {
  // ✅ NUEVO: Para las pestañas

  Map<String, dynamic>? _fullIntervention;
  bool _isLoading = true;

  // ✅ NUEVO: Controlador de pestañas
  late TabController _tabController;

  // ✅ NUEVO: Para los contactos
  List<Map<String, dynamic>> _thirdpartyContacts = [];
  List<Map<String, dynamic>> _internalUsers = [];
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ✅ 2 pestañas
    _loadFullData();
  }

  @override
  void dispose() {
    _tabController.dispose(); // ✅ Importante: limpiar el controlador
    super.dispose();
  }

  Future<void> _loadFullData() async {
    setState(() => _isLoading = true);

    final fullData = await DolibarrService.getInterventionById(
      token: widget.token,
      interventionId: widget.intervention['id'].toString(),
    );

    setState(() {
      _fullIntervention = fullData ?? widget.intervention;
      _isLoading = false;
    });

    await _loadClientName();
    await _loadContacts();
    await _loadDocuments();
  }

  // ✅ NUEVO: Cargar contactos
  Future<void> _loadContacts() async {
    if (_fullIntervention == null) return;

    setState(() => _loadingContacts = true);

    final contactsIds =
        _fullIntervention!['contacts_ids'] as List<dynamic>? ?? [];
    final internalIds =
        _fullIntervention!['contacts_ids_internal'] as List<dynamic>? ?? [];

    // Cargar contactos del tercero
    List<Map<String, dynamic>> loadedThirdpartyContacts = [];
    for (var id in contactsIds) {
      final contact = await DolibarrService.getContactById(
        token: widget.token,
        contactId: id.toString(),
      );
      if (contact != null) {
        loadedThirdpartyContacts.add(contact);
      }
    }

    // Cargar usuarios internos
    List<Map<String, dynamic>> loadedInternalUsers = [];
    for (var id in internalIds) {
      final user = await DolibarrService.getUserById(
        token: widget.token,
        userId: id.toString(),
      );
      if (user != null) {
        loadedInternalUsers.add(user);
      }
    }

    setState(() {
      _thirdpartyContacts = loadedThirdpartyContacts;
      _internalUsers = loadedInternalUsers;
      _loadingContacts = false;
    });
  }

  Future<void> _loadClientName() async {
    final socid = _fullIntervention?['socid']?.toString();
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

  void _showEditNotesDialog() {
    final publicController = TextEditingController(
      text: _fullIntervention?['note_public'] ?? '',
    );

    final privateController = TextEditingController(
      text: _fullIntervention?['note_private'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        return 'Validada';
      case '2':
        return 'Facturada';
      case '3':
        return 'Terminada';
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
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDuration(dynamic seconds) {
    if (seconds == null || seconds == '' || seconds == '0') return 'N/A';
    try {
      final totalSeconds = int.parse(seconds.toString());
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      if (hours > 0) {
        return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
      } else {
        return '$minutes min';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final intervention = _fullIntervention ?? widget.intervention;
    final status = intervention['statut']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(intervention['ref'] ?? 'Intervención'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditNotesDialog,
          ),
        ],
        bottom: TabBar(
          // Barra de pestañas
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.description), text: 'Intervención'),
            Tab(icon: Icon(Icons.contacts), text: 'Contactos'),
            Tab(icon: Icon(Icons.attach_file), text: 'Archivos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // NUEVO: Contenido de las pestañas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Pestaña 1: Intervención
                      _buildInterventionTab(intervention),
                      // Pestaña 2: Contactos
                      _buildContactsTab(),
                      // Pestaña 3: archivos
                      _buildFilesTab(intervention),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // NUEVO: Pestaña de Intervención
  Widget _buildInterventionTab(Map<String, dynamic> intervention) {
    final lines = intervention['lines'] as List<dynamic>? ?? [];
    final status = intervention['statut']?.toString(); // ✅ corregido

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Status movido aquí dentro de la pestaña
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getStatusColor(status)),
              ),
              child: Row(
                children: [
                  Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                  const SizedBox(width: 10),
                  Text(
                    'Estado: ${_getStatusLabel(status)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _getStatusColor(status),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Información principal
          _buildSection(
            context,
            title: 'Información General',
            icon: Icons.info,
            children: [
              _buildInfoRow(
                'Descripción',
                intervention['description'] ?? 'N/A',
              ),
              const Divider(),
              _buildInfoRow('Cliente', _clientName ?? 'Cargando...'),
              if (intervention['ref_client'] != null &&
                  intervention['ref_client'].toString().isNotEmpty) ...[
                const Divider(),
                _buildInfoRow('Ref. Cliente', intervention['ref_client']),
              ],
            ],
          ),

          // Notas
          if (intervention['note_public'] != null &&
              intervention['note_public'].toString().isNotEmpty)
            _buildSection(
              context,
              title: 'Nota Pública (Cliente)',
              icon: Icons.visibility,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    intervention['note_public'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),

          if (intervention['note_private'] != null &&
              intervention['note_private'].toString().isNotEmpty)
            _buildSection(
              context,
              title: 'Nota Privada (Interna)',
              icon: Icons.lock,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    intervention['note_private'],
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),

          // Fechas
          _buildSection(
            context,
            title: 'Fechas',
            icon: Icons.calendar_today,
            children: [
              _buildInfoRow('Creación', _formatDate(intervention['datec'])),
              if (intervention['dateo'] != null &&
                  intervention['dateo'].toString().isNotEmpty) ...[
                const Divider(),
                _buildInfoRow(
                  'Fecha operación',
                  _formatDate(intervention['dateo']),
                ),
              ],
              if (intervention['duration'] != null &&
                  intervention['duration'].toString() != '0') ...[
                const Divider(),
                _buildInfoRow(
                  'Duración total',
                  _formatDuration(intervention['duration']),
                ),
              ],
            ],
          ),

          // Líneas de intervención
          _buildSection(
            context,
            title: 'Líneas de Intervención (${lines.length})',
            icon: Icons.list,
            children: lines.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No hay líneas agregadas',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ]
                : lines.map((line) {
                    // Dolibarr devuelve 'desc' en las líneas, con fallback a 'description'
                    final lineDesc =
                        (line['desc'] != null &&
                            line['desc'].toString().isNotEmpty)
                        ? line['desc']
                        : (line['description'] ?? 'Sin descripción');

                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.description, size: 20),
                          title: Text(
                            lineDesc,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (line['date'] != null)
                                Text(
                                  'Fecha: ${_formatDate(line['date'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              if (line['duration'] != null)
                                Text(
                                  'Duración: ${_formatDuration(line['duration'])}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (line != lines.last) const Divider(),
                      ],
                    );
                  }).toList(),
          ),

          const SizedBox(height: 16),

          // NUEVO: Botón "¿Qué desea hacer?" con menú de acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showActionsMenu(context, status),
              icon: const Icon(Icons.menu),
              label: const Text(
                '¿Qué desea hacer?',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // NUEVO: Menú de acciones según status
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

            // Agregar línea — siempre visible
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Agregar Línea'),
              subtitle: const Text('Agregar detalle a la intervención'),
              onTap: () {
                Navigator.pop(context);
                _showAddLineDialog();
              },
            ),

            // Validar — solo si es Borrador (0)
            if (status == '0')
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check_circle, color: Colors.white),
                ),
                title: const Text('Validar Intervención'),
                subtitle: const Text('Cambiar de borrador a validada'),
                onTap: () {
                  Navigator.pop(context);
                  _validateIntervention();
                },
              ),

            // Cerrar — si está Validada (1) o En proceso (2)
            if (status == '1' || status == '2')
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.lock, color: Colors.white),
                ),
                title: const Text('Cerrar Intervención'),
                subtitle: const Text('Marcar como terminada'),
                onTap: () {
                  Navigator.pop(context);
                  _closeIntervention();
                },
              ),

            // Reabrir — solo si está Terminada (3)
            if (status == '3')
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.lock_open, color: Colors.white),
                ),
                title: const Text('Reabrir Intervención'),
                subtitle: const Text('Volver a poner en proceso'),
                onTap: () {
                  Navigator.pop(context);
                  _reopenIntervention();
                },
              ),

            // Eliminar — siempre visible
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.delete, color: Colors.white),
              ),
              title: const Text(
                'Eliminar Intervención',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Esta acción no se puede deshacer'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteIntervention();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Necesitas este método ya que _buildInterventionTab lo usa
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

  // ✅ NUEVO: Pestaña de Contactos
  Widget _buildContactsTab() {
    if (_loadingContacts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_thirdpartyContacts.isEmpty && _internalUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hay contactos asignados',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contactos del Tercero
        if (_thirdpartyContacts.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.business, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Contactos del Cliente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._thirdpartyContacts.map((contact) {
            final firstName = contact['firstname'] ?? '';
            final lastName = contact['lastname'] ?? '';
            final fullName = '$firstName $lastName'.trim();
            final position = contact['poste'] ?? '';
            final email = contact['email'] ?? '';
            final phone = contact['phone_pro'] ?? contact['phone_mobile'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  fullName.isNotEmpty ? fullName : 'Sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (position.isNotEmpty)
                      Text(
                        position,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (email.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.email, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(phone, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],

        // Usuarios Internos
        if (_internalUsers.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.engineering, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Técnicos/Responsables',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._internalUsers.map((user) {
            final firstName = user['firstname'] ?? '';
            final lastName = user['lastname'] ?? '';
            final fullName = '$firstName $lastName'.trim();
            final job = user['job'] ?? '';
            final email = user['email'] ?? '';
            final phone = user['office_phone'] ?? user['user_mobile'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  fullName.isNotEmpty ? fullName : 'Sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.isNotEmpty)
                      Text(
                        job,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (email.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.email, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(phone, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  // Lista de documentos
  List<Map<String, dynamic>> _documents = [];
  bool _loadingDocuments = false;
  String? _clientName;

  // Cargar documentos (agregar al initState después de _loadFullData)
  Future<void> _loadDocuments() async {
    if (_fullIntervention == null) return;

    setState(() => _loadingDocuments = true);

    final docs = await DolibarrService.getInterventionDocuments(
      token: widget.token,
      interventionId: _fullIntervention!['id'].toString(),
    );

    setState(() {
      _documents = docs.cast<Map<String, dynamic>>();
      _loadingDocuments = false;
    });
  }

  // Pestaña de Archivos
  Widget _buildFilesTab(Map<String, dynamic> intervention) {
    if (_loadingDocuments) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Botón subir archivo
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              // 1. Mostrar opciones: Cámara o Galería
              final ImagePicker picker = ImagePicker();
              final XFile? image = await showModalBottomSheet<XFile>(
                context: context,
                builder: (BuildContext context) {
                  return SafeArea(
                    child: Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Galería'),
                          onTap: () async {
                            final img = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            Navigator.pop(context, img);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.camera_alt),
                          title: const Text('Cámara'),
                          onTap: () async {
                            final img = await picker.pickImage(
                              source: ImageSource.camera,
                            );
                            Navigator.pop(context, img);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );

              if (image != null) {
                // 2. Mostrar indicador de carga
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // 3. Llamar al servicio de subida
                final interventionRef =
                    _fullIntervention?['ref'] ?? intervention['ref'];

                final extension = image.name.contains('.')
                    ? image.name.split('.').last.toLowerCase()
                    : 'jpg';
                final cleanFilename = 'IMG_$interventionRef.$extension';

                final result = await DolibarrService.uploadDocument(
                  interventionRef: interventionRef,
                  filePath: image.path,
                  filename: cleanFilename,
                );

                // 4. Quitar el indicador de carga y mostrar resultado
                Navigator.pop(context); // Cierra el loading

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Evidencia subida correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Refrescar la lista de documentos aquí
                  await _loadDocuments();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: ${result['message']}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Subir Evidencia'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Lista de archivos
        Expanded(
          child: _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.folder_open,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay archivos vinculados',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];

                    // ✅ TEMPORAL: Ver estructura completa
                    print('\n📄 Documento $index:');
                    print('filename: ${doc['filename']}');
                    print('name: ${doc['name']}');
                    print('filepath: ${doc['filepath']}');
                    print('relativename: ${doc['relativename']}');
                    print('level1name: ${doc['level1name']}');

                    final filename =
                        doc['filename'] ?? doc['name'] ?? 'Sin nombre';
                    final size = doc['size'];
                    final date = doc['date'];
                    final contentType = doc['content-type'] ?? '';

                    // Determinar ícono según tipo
                    IconData fileIcon = Icons.insert_drive_file;
                    Color iconColor = Colors.grey;

                    if (contentType.contains('image')) {
                      fileIcon = Icons.image;
                      iconColor = Colors.blue;
                    } else if (contentType.contains('pdf') ||
                        filename.endsWith('.pdf')) {
                      fileIcon = Icons.picture_as_pdf;
                      iconColor = Colors.red;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(fileIcon, color: iconColor),
                        ),
                        title: Text(
                          filename,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (size != null)
                              Text(
                                '${(size / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (date != null)
                              Text(
                                _formatDate(date),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () async {
                            await _downloadFile(doc);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Método para descargar archivo
  Future<void> _downloadFile(Map<String, dynamic> doc) async {
    // ✅ Obtener el filename
    String? filename = doc['filename'] ?? doc['name'] ?? doc['relativename'];

    // ✅ Obtener la referencia de la intervención
    final interventionRef =
        _fullIntervention?['ref'] ?? widget.intervention['ref'];

    print('\n📥 Descargando:');
    print('Filename: $filename');
    print('Ref: $interventionRef');

    if (filename == null || interventionRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Información incompleta'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await DolibarrService.downloadDocument(
      token: widget.token,
      interventionRef: interventionRef,
      filename: filename,
    );

    if (!mounted) return;
    Navigator.pop(context); // Cerrar loading

    if (result['success']) {
      // Intentar abrir el archivo
      try {
        await OpenFilex.open(result['filePath']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Archivo descargado y abierto'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error abriendo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Archivo guardado en: ${result['filePath']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLineDialog() {
    final descController = TextEditingController();
    final durationController = TextEditingController(text: '1');
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Agregar Línea'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción detallada',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Selector de fecha
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
                const SizedBox(height: 16),

                // NUEVO: Selector de hora
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
                      labelText: 'Hora de inicio',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duración (horas)',
                    border: OutlineInputBorder(),
                    suffixText: 'horas',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                if (descController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La descripción es obligatoria'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                // Combinar fecha y hora
                final dateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                await _addLine(
                  descController.text,
                  dateTime,
                  durationController.text,
                );
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addLine(
    String description,
    DateTime date,
    String duration,
  ) async {
    final durationInSeconds = (double.tryParse(duration) ?? 1) * 3600;
    final dateUtc = date.toUtc();
    final dateTimestamp = dateUtc.millisecondsSinceEpoch ~/ 1000;

    final result = await DolibarrService.addInterventionLine(
      token: widget.token,
      interventionId: widget.intervention['id'].toString(),
      description: description,
      date: dateTimestamp.toString(),
      duration: durationInSeconds.toInt().toString(),
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Línea agregada'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InterventionDetailScreen(
            intervention: widget.intervention,
            token: widget.token,
          ),
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
  }

  Future<void> _updateNotes(String publicNote, String privateNote) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await DolibarrService.updateInterventionNotes(
      token: widget.token,
      interventionId: int.parse(widget.intervention['id'].toString()),
      notePublic: publicNote,
      notePrivate: privateNote,
    );

    if (!mounted) return;

    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notas actualizadas'),
          backgroundColor: Colors.green,
        ),
      );

      _loadFullData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error actualizando notas'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _validateIntervention() async {
    final result = await DolibarrService.validateIntervention(
      token: widget.token,
      interventionId: widget.intervention['id'].toString(),
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Intervención validada'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _closeIntervention() async {
    final result = await DolibarrService.closeIntervention(
      token: widget.token,
      interventionId: widget.intervention['id'].toString(),
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Intervención cerrada'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadFullData(); // Recargar para reflejar el nuevo status
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reopenIntervention() async {
    final result = await DolibarrService.reopenIntervention(
      token: widget.token,
      interventionId: widget.intervention['id'].toString(),
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Intervención reabierta'),
          backgroundColor: Colors.purple,
        ),
      );
      _loadFullData(); // Recargar para reflejar el nuevo status
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteIntervention() async {
    final result = await DolibarrService.deleteIntervention(
      token: widget.token,
      interventionId: widget.intervention['id'].toString(),
    );

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Intervención eliminada'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDeleteIntervention() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar intervención'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta intervención? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteIntervention();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
