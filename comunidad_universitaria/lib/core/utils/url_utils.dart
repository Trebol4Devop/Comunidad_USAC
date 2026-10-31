import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlUtils {
  static Future<bool> openUrl(BuildContext context, String urlString) async {
    try {
      String formattedUrl = urlString.trim();
      if (formattedUrl.isEmpty) return false;

      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://') &&
          !formattedUrl.startsWith('mailto:') &&
          !formattedUrl.startsWith('tel:')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final uri = Uri.parse(formattedUrl);
      final allowedScheme = {'http', 'https', 'mailto', 'tel'};
      if (!allowedScheme.contains(uri.scheme.toLowerCase()) ||
          ((uri.scheme == 'http' || uri.scheme == 'https') &&
              (uri.host.isEmpty || uri.userInfo.isNotEmpty))) {
        throw const FormatException('Unsupported external URL');
      }

      var launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (launched) return true;

      if (context.mounted) {
        copyToClipboard(
          context,
          formattedUrl,
          message:
              'No se pudo abrir el enlace. Se copió para que puedas pegarlo.',
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir el enlace. Comprueba que sea válido e inténtalo de nuevo.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  static void copyToClipboard(
    BuildContext context,
    String text, {
    String message = 'Enlace copiado al portapapeles',
  }) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
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
