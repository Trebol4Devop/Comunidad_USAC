import 'package:flutter/material.dart';
import '../../../shared/widgets/image_viewer_dialog.dart';

/// Un componente de medios con estilo Discord para adjuntos de imagen y GIF.
/// Controla estrictamente las dimensiones (ancho y alto máximos) para evitar
/// que las imágenes se vean desproporcionadas, excesivamente anchas o recortadas.
class DiscordMediaAttachment extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final bool isGif;
  final double? maxWidth;
  final double maxHeight;
  final double minHeight;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const DiscordMediaAttachment({
    super.key,
    required this.imageUrl,
    this.title,
    this.isGif = false,
    this.maxWidth = 500,
    this.maxHeight = 300,
    this.minHeight = 120,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(8);

    // Discord slate backgrounds for image containers
    final containerBg = isDark ? const Color(0xFF1E1F22) : const Color(0xFFE2E8F0);
    final borderColor = isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 500,
          maxHeight: maxHeight,
          minHeight: minHeight,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: radius,
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap ??
                    () => ImageViewerDialog.show(
                          context,
                          imageUrl: imageUrl,
                          title: title,
                        ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: minHeight,
                          color: containerBg,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: minHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: containerBg,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Text(
                                'No se pudo cargar la imagen',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Badge GIF or Zoom Pill
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isGif) ...[
                              const Text(
                                'GIF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ] else ...[
                              const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                              const SizedBox(width: 3),
                              const Text(
                                'Ampliar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
