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
        // Encabezado de la barra lateral
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
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'MÁS POPULARES',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? const Color(0xFF949BA4) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'TOP 5',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
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

        // Listado de los 5 servidores o subservidores
        Expanded(
          child: popularServers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Sin actividad registrada aún',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  itemCount: popularServers.length.clamp(0, 5),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      width: 260,
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

    // Colores de la medalla de ranking
    Color rankBg;
    Color rankText;
    if (rank == 1) {
      rankBg = const Color(0xFFF59E0B).withValues(alpha: 0.2);
      rankText = const Color(0xFFD97706);
    } else if (rank == 2) {
      rankBg = const Color(0xFF64748B).withValues(alpha: 0.18);
      rankText = const Color(0xFF64748B);
    } else if (rank == 3) {
      rankBg = const Color(0xFFB45309).withValues(alpha: 0.18);
      rankText = const Color(0xFFB45309);
    } else {
      rankBg = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);
      rankText = isDark ? const Color(0xFF949BA4) : Colors.grey.shade600;
    }

    final cardBg = isSelected
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08)
        : (isDark ? const Color(0xFF313338) : Colors.white);

    final cardBorder = isSelected
        ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.2)
        : Border.all(color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0), width: 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onSelectServer(item.server),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: cardBorder,
          ),
          child: Row(
            children: [
              // Posición en el Ranking
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rankBg,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: rankText,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Ícono del servidor
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.server.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.server.icon,
                  size: 17,
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
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
                            color: item.server.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.server.shortCode,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: item.server.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.facultyName,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade600,
                          ),
                        ),
                        if (rank <= 3) ...[
                          const Spacer(),
                          Icon(
                            Icons.trending_up,
                            size: 12,
                            color: const Color(0xFF16A34A),
                          ),
                        ],
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
