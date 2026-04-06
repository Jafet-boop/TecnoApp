import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // Extraer datos del usuario
    final String userName = userData['login'] ?? 'Usuario';
    final String firstName = userData['firstname'] ?? '';
    final String lastName = userData['lastname'] ?? '';
    final String fullName = firstName.isNotEmpty && lastName.isNotEmpty
        ? '$firstName $lastName'
        : userName;
    final String email = userData['email'] ?? 'No registrado';
    final String userId = userData['id']?.toString() ?? '-';
    final bool isAdmin = userData['admin'] == '1';
    final String job = userData['job'] ?? 'No especificado';
    final String phone = userData['office_phone'] ?? 'No registrado';
    final String mobile = userData['user_mobile'] ?? 'No registrado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header con foto de perfil
            _buildHeader(fullName, userName, isAdmin),
            
            const SizedBox(height: 16),
            
            // Sección: Información Personal
            _buildSection(
              context,
              title: 'Información Personal',
              icon: Icons.person,
              children: [
                _buildInfoTile(
                  icon: Icons.badge,
                  label: 'Nombre Completo',
                  value: fullName,
                ),
                _buildInfoTile(
                  icon: Icons.account_circle,
                  label: 'Usuario',
                  value: userName,
                ),
                _buildInfoTile(
                  icon: Icons.numbers,
                  label: 'ID Usuario',
                  value: userId,
                ),
                _buildInfoTile(
                  icon: Icons.work,
                  label: 'Puesto',
                  value: job,
                ),
              ],
            ),
            
            // Sección: Contacto
            _buildSection(
              context,
              title: 'Información de Contacto',
              icon: Icons.contact_mail,
              children: [
                _buildInfoTile(
                  icon: Icons.email,
                  label: 'Correo Electrónico',
                  value: email,
                ),
                _buildInfoTile(
                  icon: Icons.phone,
                  label: 'Teléfono Oficina',
                  value: phone,
                ),
                _buildInfoTile(
                  icon: Icons.phone_android,
                  label: 'Teléfono Móvil',
                  value: mobile,
                ),
              ],
            ),
            
            // Sección: Rol y Permisos
            _buildSection(
              context,
              title: 'Rol y Permisos',
              icon: Icons.security,
              children: [
                _buildInfoTile(
                  icon: Icons.admin_panel_settings,
                  label: 'Rol',
                  value: isAdmin ? 'Administrador' : 'Usuario',
                  valueColor: isAdmin ? Colors.orange : Colors.blue,
                ),
                _buildInfoTile(
                  icon: Icons.verified_user,
                  label: 'Estado',
                  value: userData['statut'] == '1' ? 'Activo' : 'Inactivo',
                  valueColor: userData['statut'] == '1' ? Colors.green : Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Header con avatar y nombre
  Widget _buildHeader(String fullName, String userName, bool isAdmin) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Text(
                  _getInitials(fullName),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Nombre completo
            Text(
              fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            
            // Username
            Text(
              '@$userName',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            
            // Badge de admin
            if (isAdmin)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Administrador',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Sección con título
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
              Icon(icon, color: Colors.blue),
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
              child: Column(
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Item de información
  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Obtener iniciales del nombre
String _getInitials(String name) {
  // 1. Limpiamos espacios y verificamos si realmente hay texto
  String cleanName = name.trim();
  if (cleanName.isEmpty) {
    return 'U'; // Valor por defecto si no hay nombre
  }
  List<String> nameParts = cleanName.split(' ');
  try {
    // 2. Si tiene al menos dos palabras (Nombre y Apellido)
    if (nameParts.length >= 2 && nameParts[0].isNotEmpty && nameParts[1].isNotEmpty) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } 
    // 3. Si solo tiene una palabra (Solo nombre)
    if (nameParts[0].isNotEmpty) {
      return nameParts[0][0].toUpperCase();
    }
  } catch (e) {
    // Por si algo muy raro pasa (como caracteres especiales extraños)
    return 'U';
  }
  return 'U';
}
}