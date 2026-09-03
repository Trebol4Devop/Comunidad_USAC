import 'package:flutter/material.dart';
import '../../../../core/constants/categories.dart';
import '../../models/discord_forum_models.dart';

class ForumCarreraPickerDialog extends StatefulWidget {
  final Function(ForumServer server) onServerSelected;

  const ForumCarreraPickerDialog({
    super.key,
    required this.onServerSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(ForumServer server) onServerSelected,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ForumCarreraPickerDialog(onServerSelected: onServerSelected),
    );
  }

  @override
  State<ForumCarreraPickerDialog> createState() => _ForumCarreraPickerDialogState();
}

class _ForumCarreraPickerDialogState extends State<ForumCarreraPickerDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getAllCarrerasFlat() {
    final List<Map<String, dynamic>> results = [];
    for (var fac in USACConstants.facultades) {
      final facNombre = fac['nombre']?.toString() ?? 'Facultad';
      final facId = fac['id']?.toString() ?? 'todas';
      final carreras = fac['carreras'] as List<dynamic>? ?? [];

      for (var c in carreras) {
        results.add({
          'facultadId': facId,
          'facultadNombre': facNombre,
          'carreraId': c['id']?.toString() ?? 'todas',
          'carreraNombre': c['nombre']?.toString() ?? 'Carrera',
          'codigo': c['codigo']?.toString() ?? '',
          'sede': c['sede']?.toString() ?? 'Campus Central',
        });
      }
    }
    return results;
  }

  IconData _getIconForFacultad(String facId) {
    switch (facId) {
      case '01':
        return Icons.eco;
      case '02':
        return Icons.architecture;
      case '03':
        return Icons.trending_up;
      case '04':
        return Icons.gavel;
      case '05':
        return Icons.medical_services;
      case '06':
        return Icons.biotech;
      case '07':
        return Icons.psychology;
      case '08':
        return Icons.engineering;
      case '09':
        return Icons.medical_information;
      case '10':
        return Icons.pets;
      default:
        return Icons.school;
    }
  }

  Color _getColorForFacultad(String facId) {
    switch (facId) {
      case '01':
        return const Color(0xFF16A34A);
      case '02':
        return const Color(0xFF059669);
      case '03':
        return const Color(0xFF0D9488);
      case '04':
        return const Color(0xFF7C3AED);
      case '05':
        return const Color(0xFFDC2626);
      case '06':
        return const Color(0xFFE11D48);
      case '07':
        return const Color(0xFFD97706);
      case '08':
        return const Color(0xFF0284C7);
      case '09':
        return const Color(0xFF4F46E5);
      case '10':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF004B87);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allCarreras = _getAllCarrerasFlat();

    final filtered = allCarreras.where((c) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      final cName = (c['carreraNombre'] as String).toLowerCase();
      final fName = (c['facultadNombre'] as String).toLowerCase();
      final code = (c['codigo'] as String).toLowerCase();
      return cName.contains(q) || fName.contains(q) || code.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.explore_outlined, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Explorar Carreras (Servidores)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          'Selecciona tu carrera para acceder a sus canales exclusivos',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por carrera, facultad o código...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No se encontraron carreras que coincidan con "$_searchQuery".'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final facId = item['facultadId'] as String;
                          final color = _getColorForFacultad(facId);
                          final icon = _getIconForFacultad(facId);
                          final carreraName = item['carreraNombre'] as String;
                          final facultadName = item['facultadNombre'] as String;
                          final carreraId = item['carreraId'] as String;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(
                              carreraName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            subtitle: Text(
                              facultadName,
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () {
                              final short = carreraName.length > 4
                                  ? carreraName.substring(0, 4).toUpperCase()
                                  : carreraName.toUpperCase();

                              final newServer = ForumServer(
                                id: carreraId,
                                name: carreraName,
                                shortCode: short,
                                icon: icon,
                                facultadId: facId,
                                carreraId: carreraId,
                                description: 'Servidor oficial de $carreraName ($facultadName).',
                                color: color,
                              );

                              widget.onServerSelected(newServer);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
