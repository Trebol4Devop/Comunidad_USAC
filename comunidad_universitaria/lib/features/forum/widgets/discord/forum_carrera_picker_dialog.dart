import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/categories.dart';
import '../../../../core/constants/zanate_colors.dart';
import '../../models/discord_forum_models.dart';

class ForumCarreraPickerDialog extends StatefulWidget {
  final Function(ForumServer server) onServerSelected;

  const ForumCarreraPickerDialog({super.key, required this.onServerSelected});

  static Future<void> show(
    BuildContext context, {
    required Function(ForumServer server) onServerSelected,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) =>
          ForumCarreraPickerDialog(onServerSelected: onServerSelected),
    );
  }

  @override
  State<ForumCarreraPickerDialog> createState() =>
      _ForumCarreraPickerDialogState();
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

      final cleanFacNombre = facNombre
          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
          .replaceAll(RegExp(r'\s*[/|-]\s*General.*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      for (var c in carreras) {
        var cName = c['nombre']?.toString() ?? 'Carrera';
        cName = cName
            .replaceAll('(Campus Central)', '')
            .replaceAll('(Extensión)', ' - Extensión')
            .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
            .replaceAll(
              RegExp(
                r'\s*[/|-]\s*(Cursos Básicos|General).*',
                caseSensitive: false,
              ),
              '',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        results.add({
          'facultadId': facId,
          'facultadNombre': cleanFacNombre,
          'carreraId': c['id']?.toString() ?? 'todas',
          'carreraNombre': cName,
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

  Color _getColorForFacultad(String facId, {bool isDark = false}) {
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
        return const Color(0xFF004B87);
      case '10':
        return const Color(0xFF9333EA);
      default:
        return isDark ? const Color(0xFF0066CC) : const Color(0xFF004B87);
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

    final borderColor = isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;
    final primaryTextColor = isDark ? Colors.white : ZanateColors.zanateDark;
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 0.8),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.compass,
                        color: ZanateColors.zanateAccent,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agregar servidor',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.3,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Elige una carrera o facultad para añadirla a tu lista',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: PhosphorIcon(PhosphorIconsRegular.x, size: 18, color: secondaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 13.5,
                  color: primaryTextColor,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por carrera, facultad o código...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                  ),
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: PhosphorIcon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : ZanateColors.surfaceBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor, width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor, width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: ZanateColors.zanateAccent,
                      width: 1.5,
                    ),
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
                            PhosphorIcon(
                              PhosphorIconsRegular.magnifyingGlass,
                              size: 36,
                              color: secondaryTextColor.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No se encontraron carreras que coincidan con "$_searchQuery".',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          color: borderColor,
                        ),
                        itemBuilder: (ctx, i) {
                          final item = filtered[i];
                          final facId = item['facultadId'] as String;
                          final color = _getColorForFacultad(
                            facId,
                            isDark: isDark,
                          );
                          final icon = _getIconForFacultad(facId);
                          final carreraName = item['carreraNombre'] as String;
                          final facultadName = item['facultadNombre'] as String;
                          final carreraId = item['carreraId'] as String;

                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  icon,
                                  color: color,
                                  size: 20,
                                ),
                              ),
                            ),
                            title: Text(
                              carreraName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: primaryTextColor,
                              ),
                            ),
                            subtitle: Text(
                              facultadName,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PhosphorIcon(
                              PhosphorIconsRegular.caretRight,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                            onTap: () {
                              final short = carreraName.length > 4
                                  ? carreraName.substring(0, 4).toUpperCase()
                                  : carreraName.toUpperCase();

                              final newServer = ForumServer(
                                id: facId == 'todas'
                                    ? carreraId
                                    : '${facId}_$carreraId',
                                name: carreraName,
                                shortCode: short,
                                icon: icon,
                                facultadId: facId,
                                carreraId: carreraId,
                                description:
                                    'Canal de $carreraName · $facultadName',
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
