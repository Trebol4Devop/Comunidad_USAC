import 'package:flutter/material.dart';

enum IdentityMode {
  forumAnonymous,
  marketplaceVerified,
}

class IdentityBadgeChip extends StatelessWidget {
  final IdentityMode mode;
  final String displayName;
  final String? carne;
  final bool isVerified;
  final VoidCallback? onSwitchIdentity;

  const IdentityBadgeChip({
    super.key,
    required this.mode,
    required this.displayName,
    this.carne,
    this.isVerified = false,
    this.onSwitchIdentity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (mode == IdentityMode.forumAnonymous) {
      // FORO ANÓNIMO: Tratamiento visual neutro / privacy-first / dark tones
      final chipBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      final borderColor = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.masks_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Publicando como: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Modo Anónimo (Tu carné y nombre real están ocultos)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSwitchIdentity != null)
              InkWell(
                onTap: onSwitchIdentity,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cached,
                        size: 13,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Cambiar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // MARKETPLACE: Lenguaje visual de confianza y transparencia institucional
      final chipBg = isDark
          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
          : const Color(0xFFECFDF5);
      final borderColor = const Color(0xFF10B981).withValues(alpha: 0.5);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isVerified ? Icons.verified : Icons.verified_user_outlined,
                size: 16,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Publicando con tu perfil: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF065F46),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Verificado',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVerified
                        ? 'Identidad validada con carné institucional USAC'
                        : 'Perfil estudiantil de contacto directo',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            if (onSwitchIdentity != null)
              InkWell(
                onTap: onSwitchIdentity,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 13,
                        color: Color(0xFF059669),
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Ajustes',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }
}
