import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/url_utils.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: MaxWidthContainer(
          maxWidth: 900,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Normas Comunitarias & Descargo Legal',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Comunidad Universitaria es una iniciativa estudiantil independiente, libre y sin fines de lucro entre compañeros universitarios.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Reglas del Foro y Grupos
              Text(
                'Reglas de Convivencia Estudiantil',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),

              _buildRuleTile(
                context,
                number: '1',
                title: 'Respeto mutuo y fraternidad universitaria',
                description:
                    'Queda estrictamente prohibido el acoso, las faltas de respeto, discriminación o difamación entre compañeros o hacia catedráticos.',
                icon: Icons.favorite_outline,
              ),
              _buildRuleTile(
                context,
                number: '2',
                title: 'Veracidad y enlaces limpios',
                description:
                    'Solo comparte enlaces legítimos de grupos académicos (WhatsApp, Telegram, Discord, Drive). No se permiten acortadores con publicidad ni enlaces maliciosos.',
                icon: Icons.link_outlined,
              ),
              _buildRuleTile(
                context,
                number: '3',
                title: 'Prohibición de venta de exámenes o fraude académico',
                description:
                    'La comunidad está pensada para apoyarnos con resolución de dudas, resúmenes y material libre. No se tolera el comercio de notas, parciales filtrados ni suplantación.',
                icon: Icons.block_outlined,
              ),
              _buildRuleTile(
                context,
                number: '4',
                title: 'Protección de Privacidad y Seudónimos',
                description:
                    'Utiliza seudónimos estudiantiles para formular preguntas con confianza. No publiques datos personales sensibles como números de teléfono privados, DPIs o direcciones personales.',
                icon: Icons.lock_outline,
              ),

              const SizedBox(height: 24),

              // Reglas del Marketplace y Emprendimientos
              Text(
                'Normas del Marketplace & Servicios Estudiantiles',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 12),

              _buildRuleTile(
                context,
                number: '5',
                title: 'Trato directo y sin intermediación financiera',
                description:
                    'La plataforma no interviene en las transacciones comerciales, no custodia dinero ni cobra comisiones. Toda compraventa, entrega o coordinación de tutoría se realiza de forma directa y voluntaria entre los estudiantes.',
                icon: Icons.handshake_outlined,
              ),
              _buildRuleTile(
                context,
                number: '6',
                title:
                    'Prohibición estricta de sustancias y productos ilegales',
                description:
                    'Queda terminantemente prohibido publicar bebidas alcohólicas, sustancias ilícitas, medicamentos bajo prescripción médica, armas o cualquier artículo prohibido por el reglamento universitario y las leyes de Guatemala.',
                icon: Icons.gavel_outlined,
              ),
              _buildRuleTile(
                context,
                number: '7',
                title: 'Seguridad en puntos de encuentro',
                description:
                    'Recomendamos realizar las entregas de comidas, libros o asesorías en áreas comunes y transitadas del campus o sede durante las jornadas diurnas o cambios de clase.',
                icon: Icons.place_outlined,
              ),

              const SizedBox(height: 24),

              // Descargo de Responsabilidad (Disclaimer)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFFB45309),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Descargo de Responsabilidad Legal e Independencia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Comunidad Universitaria es una plataforma y directorio estudiantil independiente y sin fines de lucro. No representa, no forma parte ni actúa en nombre de las autoridades de la Universidad de San Carlos de Guatemala (USAC). Los datos de pensums, materias y facultades se basan en publicaciones de libre acceso con carácter exclusivamente informativo.\n\nLos administradores de la plataforma no se hacen responsables de los acuerdos particulares, compras, ventas o contenidos intercambiados en enlaces de terceros.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Portales Oficiales de la USAC
              Text(
                'Enlaces Externos de Referencia (Portales de Unidades Académicas)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Los siguientes enlaces conducen a los sitios web institucionales externos de cada facultad:',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: USACConstants.facultades
                    .where((f) => f['id'] != 'todas')
                    .map(
                      (f) => ActionChip(
                        avatar: const Icon(Icons.open_in_new, size: 14),
                        label: Text(
                          f['nombre'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () =>
                            UrlUtils.openUrl(context, f['sitio'].toString()),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleTile(
    BuildContext context, {
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2541) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
