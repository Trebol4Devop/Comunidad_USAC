import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
        return PhosphorIconsRegular.plant;
      case '02':
        return PhosphorIconsRegular.compassTool;
      case '03':
        return PhosphorIconsRegular.trendUp;
      case '04':
        return PhosphorIconsRegular.scales;
      case '05':
        return PhosphorIconsRegular.firstAidKit;
      case '06':
        return PhosphorIconsRegular.flask;
      case '07':
        return PhosphorIconsRegular.brain;
      case '08':
        return PhosphorIconsRegular.gear;
      case '09':
        return PhosphorIconsRegular.stethoscope;
      case '10':
        return PhosphorIconsRegular.pawPrint;
      default:
        return PhosphorIconsRegular.graduationCap;
    }
  }

  Color _getColorForFacultad(String facId, {bool isDark = false}) {
    return isDark ? ZanateColors.zanateEyeYellow : ZanateColors.zanateBlack;
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

    final borderColor = ZanateColors.border(isDark);
    final primaryTextColor = ZanateColors.textPrimary(isDark);
    final secondaryTextColor = ZanateColors.textMuted(isDark);

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      backgroundColor: ZanateColors.bg(isDark),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: screenSize.height * 0.86,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.compass,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
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
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            letterSpacing: -0.3,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Elige una carrera o facultad para añadirla a tu lista',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ZanateColors.zanateEyeYellow,
                            borderRadius: BorderRadius.circular(2),
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
                  fillColor: ZanateColors.surface(isDark),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor, width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                      width: 1.6,
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
                          final logoAsset = ForumServer.getLogoAssetFor(
                            id: carreraId,
                            facultadId: facId,
                          );

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
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: ZanateColors.surface(isDark),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: ZanateColors.border(isDark),
                                  width: 1,
                                ),
                              ),
                              child: logoAsset != null
                                  ? Image.asset(
                                      logoAsset,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        icon,
                                        color: color,
                                        size: 20,
                                      ),
                                    )
                                  : Icon(
                                      icon,
                                      color: color,
                                      size: 20,
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
                                logoAsset: logoAsset,
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
