import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static Future<bool> openUrl(BuildContext context, String urlString) async {
    try {
      final uri = Uri.parse(urlString.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir el enlace: $urlString'),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URL no válida: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
  }

  static void copyToClipboard(BuildContext context, String text, {String message = 'Enlace copiado al portapapeles'}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
