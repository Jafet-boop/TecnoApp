import 'package:flutter/material.dart';
import '../services/project_service.dart';

class CreateTaskScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> project;

  const CreateTaskScreen({
    super.key,
    required this.token,
    required this.project,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey              = GlobalKey<FormState>();
  final _labelController      = TextEditingController();
  final _descriptionController = TextEditingController();
  final _workloadController   = TextEditingController(text: '1');

  DateTime _dateStart = DateTime.now();
  DateTime _dateEnd   = DateTime.now().add(const Duration(days: 1));

  String _status   = '0'; // Borrador por defecto
  String _progress = '0';
  String _priority = '0';

  bool _isCreating = false;

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    _workloadController.dispose();
    super.dispose();
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

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

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

    // Convertir horas a segundos
    final hours          = double.tryParse(_workloadController.text) ?? 1;
    final workloadSeconds = (hours * 3600).toInt();

    final result = await ProjectService.createTask(
      token:           widget.token,
      label:           _labelController.text.trim(),
      fkProject:       widget.project['id'].toString(),
      description:     _descriptionController.text.trim(),
      dateStart:       _dateStart.millisecondsSinceEpoch ~/ 1000,
      dateEnd:         _dateEnd.millisecondsSinceEpoch ~/ 1000,
      plannedWorkload: workloadSeconds,
      status:          _status,
      progress:        _progress,
      priority:        _priority,
    );

    setState(() => _isCreating = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Tarea creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
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
        title: const Text('Nueva Tarea'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Info del proyecto ────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1565C0).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_open,
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.project['title'] ?? 'Sin título',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1565C0),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.project['ref'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Título de la tarea ───────────────────────────
            _buildLabel('Título *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _labelController,
              decoration: _inputDecoration(
                hint: 'Título de la tarea',
                icon: Icons.task_alt,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'El título es obligatorio' : null,
            ),

            const SizedBox(height: 16),

            // ── Descripción ──────────────────────────────────
            _buildLabel('Descripción'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(
                hint: 'Descripción detallada de la tarea...',
                icon: Icons.description,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // ── Fechas ───────────────────────────────────────
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

            // ── Tiempo estimado ──────────────────────────────
            _buildLabel('Tiempo Estimado (horas) *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _workloadController,
              decoration: _inputDecoration(
                hint: 'Ej: 2.5',
                icon: Icons.timer_outlined,
              ).copyWith(suffixText: 'horas'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo obligatorio';
                if (double.tryParse(v) == null) return 'Ingresa un número válido';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Estado ───────────────────────────────────────
            _buildLabel('Estado'),
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
                    DropdownMenuItem(value: '1', child: Text('En curso')),
                    DropdownMenuItem(value: '2', child: Text('Finalizada')),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Progreso ─────────────────────────────────────
            _buildLabel('Progreso: $_progress%'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF1565C0),
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: const Color(0xFF1565C0),
                      overlayColor:
                          const Color(0xFF1565C0).withOpacity(0.1),
                    ),
                    child: Slider(
                      value: double.parse(_progress),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '$_progress%',
                      onChanged: (v) =>
                          setState(() => _progress = v.toInt().toString()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      Text('50%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                      Text('100%',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Prioridad ────────────────────────────────────
            _buildLabel('Prioridad'),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildPriorityCard('0', 'Normal', Colors.grey,   Icons.remove),
                const SizedBox(width: 8),
                _buildPriorityCard('1', 'Alta',   Colors.orange, Icons.arrow_upward),
                const SizedBox(width: 8),
                _buildPriorityCard('2', 'Urgente', Colors.red,   Icons.priority_high),
              ],
            ),

            const SizedBox(height: 32),

            // ── Botón Crear ──────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createTask,
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
                  _isCreating ? 'Creando...' : 'Crear Tarea',
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

            // ── Botón Cancelar ───────────────────────────────
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

  // ── Helpers UI ────────────────────────────────────────────────────────────
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
        borderSide:
            const BorderSide(color: Color(0xFF1565C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _buildDateTile({
    required DateTime date,
    required VoidCallback onTap,
  }) {
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

  Widget _buildPriorityCard(
    String value,
    String label,
    Color color,
    IconData icon,
  ) {
    final selected = _priority == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _priority = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(0.12)
                : const Color(0xFFF0F6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: selected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}