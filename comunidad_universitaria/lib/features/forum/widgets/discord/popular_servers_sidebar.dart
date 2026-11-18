import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/zanate_colors.dart';
import '../../models/discord_forum_models.dart';

/// Barra lateral fija y general que muestra el listado de las cinco
/// comunidades, servidores o subservidores más populares del foro.
class PopularServersSidebar extends StatelessWidget {
  final List<PopularServerItem> popularServers;
  final ForumServer activeServer;
  final Function(ForumServer) onSelectServer;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final bool isModal;

  const PopularServersSidebar({
    super.key,
    required this.popularServers,
    required this.activeServer,
    required this.onSelectServer,
    this.isLoading = false,
    this.onRefresh,
    this.isModal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Discord right sidebar background: #2B2D31 dark, #F8FAFC light
    final bgColor = isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : ZanateColors.subtleBorder;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado minimalista de la barra lateral
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: borderColor, width: 1.0)),
          ),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIconsBold.trendUp,
                size: 16,
                color: isDark
                    ? ZanateColors.zanateEyeYellow
                    : ZanateColors.zanateBlack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MÁS POPULARES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : ZanateColors.subtleText,
                  ),
                ),
              ),
              if (onRefresh != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: isLoading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        )
                      : PhosphorIcon(
                          PhosphorIconsRegular.arrowsClockwise,
                          size: 14,
                          color:
                              isDark ? Colors.white70 : ZanateColors.mutedText,
                        ),
                  onPressed: isLoading ? null : onRefresh,
                ),
              ],
            ],
          ),
        ),

        // Listado minimalista de servidores populares reales (sin datos falsos)
        Expanded(
          child: popularServers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.chartBar,
                          size: 24,
                          color: isDark
                              ? const Color(0xFF4E5058)
                              : ZanateColors.hintText,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin actividad registrada aún',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF949BA4)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  itemCount: popularServers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = popularServers[index];
                    final rank = index + 1;
                    return _buildServerCard(context, item, rank, isDark, theme);
                  },
                ),
        ),
      ],
    );

    if (isModal) {
      return Container(color: bgColor, child: content);
    }

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(left: BorderSide(color: borderColor, width: 1)),
      ),
      child: content,
    );
  }

  Widget _buildServerCard(
    BuildContext context,
    PopularServerItem item,
    int rank,
    bool isDark,
    ThemeData theme,
  ) {
    final isSelected =
        activeServer.id == item.server.id ||
        (activeServer.carreraId == item.server.carreraId &&
            activeServer.facultadId == item.server.facultadId);

    final cardBg = isSelected
        ? ZanateColors.zanateEyeYellow.withValues(alpha: isDark ? 0.16 : 0.22)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final cardBorder = isSelected
        ? Border.all(
            color: isDark
                ? ZanateColors.zanateEyeYellow.withValues(alpha: 0.6)
                : ZanateColors.zanateBlack,
            width: 1.2,
          )
        : Border.all(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 1.0,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelectServer(item.server),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: cardBorder,
          ),
          child: Row(
            children: [
              // Posición minimalista tipo '#1'
              SizedBox(
                width: 22,
                child: Text(
                  '#$rank',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rank == 1
                        ? (isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack)
                        : (isDark
                            ? const Color(0xFF94A3B8)
                            : ZanateColors.mutedText),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Ícono táctil o escudo con fondo sutil
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.server.resolvedLogoAsset != null
                      ? (isDark ? const Color(0xFF25262B) : const Color(0xFFF8FAFC))
                      : item.server.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.server.resolvedLogoAsset != null
                        ? (isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0))
                        : item.server.color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: item.server.resolvedLogoAsset != null
                    ? Padding(
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          item.server.resolvedLogoAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            item.server.icon,
                            size: 15,
                            color: item.server.color,
                          ),
                        ),
                      )
                    : Icon(
                        item.server.icon,
                        size: 15,
                        color: item.server.color,
                      ),
              ),
              const SizedBox(width: 8),

              // Datos del servidor / subservidor
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.server.name
                          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
                          .trim(),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : ZanateColors.zanateBlack,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.facultyName
                          .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
                          .trim(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? const Color(0xFF949BA4)
                            : ZanateColors.mutedText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Métricas de popularidad (publicaciones y reacciones)
                    Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.chatsCircle,
                          size: 11,
                          color: isDark
                              ? const Color(0xFF949BA4)
                              : ZanateColors.mutedText,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.postCount}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF949BA4)
                                : ZanateColors.subtleText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PhosphorIcon(
                          PhosphorIconsRegular.thumbsUp,
                          size: 11,
                          color: isDark
                              ? const Color(0xFF949BA4)
                              : ZanateColors.mutedText,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.likesCount}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF949BA4)
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
