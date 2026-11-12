import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';

/// Panel lateral de canales y chats directos estilo Discord (ForumChannelSidebar)
/// con lista vertical ergonómica, avatares circulares (38px), insignias de estado (10px)
/// y Tarjeta de Perfil de Usuario (User Footer Card) fija en la parte inferior con
/// degradado invernal efecto hielo.
class ForumChannelSidebar extends StatelessWidget {
  final ForumServer activeServer;
  final ForumChannel activeChannel;
  final List<ForumChannel>? channels;
  final Function(ForumChannel) onSelectChannel;
  final String? activeAlias;
  final VoidCallback? onOpenProfile;
  final double? width;

  const ForumChannelSidebar({
    super.key,
    required this.activeServer,
    required this.activeChannel,
    this.channels,
    required this.onSelectChannel,
    this.activeAlias,
    this.onOpenProfile,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF1E1F22) : const Color(0xFFF2F3F5);
    final borderColor = isDark
        ? const Color(0xFF2B2D31)
        : const Color(0xFFE3E5E8);
    final channelList =
        channels ??
        (activeServer.isGroups
            ? ForumChannel.groupsChannels
            : ForumChannel.defaultChannels);

    return Container(
      width: width,
      color: background,
      child: Column(
        children: [
          // 1. Encabezado del Servidor / Comunidad
          Container(
            height: 56,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                if (activeServer.resolvedLogoAsset != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF26282B) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Image.asset(
                      activeServer.resolvedLogoAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        activeServer.icon,
                        size: 16,
                        color: activeServer.color,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeServer.name
                            .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
                            .trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeServer.isGroups
                            ? 'Grupos de estudio'
                            : 'Comunidad universitaria',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF949BA4)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Lista scrolleable de canales o chats
          Expanded(
            child: ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
              children: [
                _sectionLabel(
                  activeServer.isGroups ? 'GRUPOS' : 'CANALES',
                  isDark,
                ),
                const SizedBox(height: 6),
                for (final channel in channelList)
                  _channelTile(
                    channel,
                    activeChannel.id == channel.id,
                    theme,
                    isDark,
                  ),
                if (!activeServer.isGroups) ...[
                  const SizedBox(height: 16),
                  _sectionLabel('PERSONAL', isDark),
                  const SizedBox(height: 6),
                  _channelTile(
                    ForumChannel.bookmarksChannel,
                    activeChannel.id == ForumChannel.bookmarksChannel.id,
                    theme,
                    isDark,
                  ),
                ],
              ],
            ),
          ),

          // 3. Tarjeta de Perfil de Usuario (User Footer Card) fija abajo a la derecha
          _buildUserFooterCard(context, isDark),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _channelTile(
    ForumChannel channel,
    bool isActive,
    ThemeData theme,
    bool isDark,
  ) {
    final activeBg = isDark ? const Color(0xFF35373C) : const Color(0xFFE2E8F0);
    final activeFg = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveFg = isDark ? const Color(0xFF949BA4) : const Color(0xFF475569);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelectChannel(channel),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Avatar circular de 36px-40px (38px) con insignia de estado online (~10px)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFF004B87).withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF2B2D31) : const Color(0xFFE2E8F0)),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF004B87).withValues(alpha: 0.45)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          channel.icon,
                          size: 19,
                          color: isActive ? const Color(0xFF004B87) : inactiveFg,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF23A55A), // Verde online Discord
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E1F22) : const Color(0xFFF2F3F5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // Nombre del canal / usuario en peso semi-bold o medium alineado verticalmente
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? activeFg : inactiveFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de perfil inferior con degradado invernal azul efecto hielo,
  /// avatar de ~44px superpuesto a la izquierda, insignia online, nombre con chevron
  /// y estado de conexión actual ("En línea").
  Widget _buildUserFooterCard(BuildContext context, bool isDark) {
    final displayName = (activeAlias != null && activeAlias!.trim().isNotEmpty)
        ? activeAlias!.trim()
        : 'Estudiante USAC';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0284C7), // Azul cielo invernal (Sky 600)
            Color(0xFF0369A1), // Azul hielo intenso (Sky 700)
            Color(0xFF075985), // Azul profundo (Sky 800)
            Color(0xFF0C4A6E), // Fondo glacial (Sky 900)
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenProfile,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Avatar del usuario actual (~44px) con aro blanco hielo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Información textual: Nombre principal con selector desplegable (chevron v)
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
