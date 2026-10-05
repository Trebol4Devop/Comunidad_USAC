import 'package:flutter/material.dart';
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
    final bgColor = isDark ? const Color(0xFF2B2D31) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado minimalista de la barra lateral
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MÁS POPULARES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFF949BA4) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  if (popularServers.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${popularServers.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                  if (onRefresh != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: isLoading ? null : onRefresh,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: isLoading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5),
                              )
                            : Icon(
                                Icons.refresh,
                                size: 14,
                                color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Comunidades con mayor actividad y aportes',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF80848E) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        // Listado minimalista de servidores populares reales (sin datos falsos)
        Expanded(
          child: popularServers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: 24,
                          color: isDark ? const Color(0xFF4E5058) : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin actividad registrada aún',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  itemCount: popularServers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
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
      return Container(
        color: bgColor,
        child: content,
      );
    }

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          left: BorderSide(color: borderColor, width: 1),
        ),
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
    final isSelected = activeServer.id == item.server.id ||
        (activeServer.carreraId == item.server.carreraId &&
            activeServer.facultadId == item.server.facultadId);

    final cardBg = isSelected
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.06)
        : (isDark ? const Color(0xFF2E3035) : Colors.white);

    final cardBorder = isSelected
        ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1)
        : Border.all(color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0), width: 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelectServer(item.server),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
            border: cardBorder,
          ),
          child: Row(
            children: [
              // Posición minimalista tipo '#1'
              SizedBox(
                width: 22,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank == 1
                        ? theme.colorScheme.primary
                        : (isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B)),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Ícono táctil con fondo sutil
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: item.server.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.server.color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.server.name,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: item.server.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            item.server.shortCode,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: item.server.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.facultyName,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    // Métricas de popularidad (publicaciones y reacciones)
                    Row(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 10,
                          color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.postCount}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 10,
                          color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.likesCount}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade600,
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
