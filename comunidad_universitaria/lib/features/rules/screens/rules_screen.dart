import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/categories.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/url_utils.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const _zanateBlack = Color(0xFF0B0D10);
  static const _subtleText = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(
                        PhosphorIconsBold.caretLeft,
                        size: 22,
                        color: _zanateBlack,
                      ),
                      tooltip: 'Regresar',
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'Normas y Descargo',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _zanateBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: MaxWidthContainer(
                  maxWidth: 720,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Zanate es una iniciativa estudiantil independiente, libre y sin fines de lucro entre compañeros universitarios.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: _subtleText,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Reglas del Foro y Grupos
                      Text(
                        'Reglas de Convivencia Estudiantil',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.2,
                          color: _zanateBlack,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildRuleTile(
                        number: '1',
                        title: 'Respeto mutuo y fraternidad universitaria',
                        description:
                            'Queda estrictamente prohibido el acoso, las faltas de respeto, discriminación o difamación entre compañeros o hacia catedráticos.',
                      ),
                      _buildRuleTile(
                        number: '2',
                        title: 'Veracidad y enlaces limpios',
                        description:
                            'Solo comparte enlaces legítimos de grupos académicos. No se permiten acortadores con publicidad ni enlaces maliciosos.',
                      ),
                      _buildRuleTile(
                        number: '3',
                        title:
                            'Prohibición de venta de exámenes o fraude académico',
                        description:
                            'La comunidad está pensada para apoyarnos con resolución de dudas, resúmenes y material libre. No se tolera el comercio de notas, parciales filtrados ni suplantación.',
                      ),
                      _buildRuleTile(
                        number: '4',
                        title: 'Protección de Privacidad y Seudónimos',
                        description:
                            'Utiliza seudónimos estudiantiles para formular preguntas con confianza. No publiques datos personales sensibles como números de teléfono privados, DPIs o direcciones personales.',
                      ),

                      const SizedBox(height: 20),

                      // Reglas del Marketplace y Emprendimientos
                      Text(
                        'Normas del Marketplace & Servicios Estudiantiles',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          letterSpacing: -0.2,
                          color: _zanateBlack,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildRuleTile(
                        number: '5',
                        title: 'Trato directo y sin intermediación financiera',
                        description:
                            'La plataforma no interviene en las transacciones comerciales, no custodia dinero ni cobra comisiones. Toda compraventa, entrega o coordinación de tutoría se realiza de forma directa y voluntaria entre los estudiantes.',
                      ),
                      _buildRuleTile(
                        number: '6',
                        title:
                            'Prohibición estricta de sustancias y productos ilegales',
                        description:
                            'Queda terminantemente prohibido publicar bebidas alcohólicas, sustancias ilícitas, medicamentos bajo prescripción médica, armas o cualquier artículo prohibido por el reglamento universitario y las leyes de Guatemala.',
                      ),
                      _buildRuleTile(
                        number: '7',
                        title: 'Seguridad en puntos de encuentro',
                        description:
                            'Recomendamos realizar las entregas de comidas, libros o asesorías en áreas comunes y transitadas del campus o sede durante las jornadas diurnas o cambios de clase.',
                      ),

                      const SizedBox(height: 20),

                      // Descargo de Responsabilidad (Disclaimer)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFDE68A),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.info,
                                  color: Color(0xFFB45309),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Descargo de Responsabilidad Legal e Independencia',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF92400E),
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Zanate es una plataforma y directorio estudiantil independiente y sin fines de lucro. No representa, no forma parte ni actúa en nombre de las autoridades de la Universidad de San Carlos de Guatemala. Los datos de pensums, materias y facultades se basan en publicaciones de libre acceso con carácter exclusivamente informativo.\n\nLos administradores de la plataforma no se hacen responsables de los acuerdos particulares, compras, ventas o contenidos intercambiados en enlaces de terceros.',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sección de Cumplimiento Legal y Privacidad
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.scales,
                                  color: _zanateBlack,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Cumplimiento legal y privacidad',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      color: _zanateBlack,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildLegalBullet(
                              boldPrefix: 'Art. 3:',
                              text:
                                  ' el proveedor no edita transmisiones ajenas; solo aprueba u oculta.',
                            ),
                            const SizedBox(height: 8),
                            _buildLegalBullet(
                              boldPrefix: 'Art. 12/13/14/16:',
                              text:
                                  ' suplantación, acceso ilícito, fraude y amenazas están prohibidos.',
                            ),
                            const SizedBox(height: 8),
                            _buildLegalBullet(
                              boldPrefix: 'Art. 20/21:',
                              text:
                                  ' retención de evidencia hasta 90 días y congelamiento legal.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Portales Oficiales de la USAC
                      Text(
                        'Portales Oficiales de Unidades Académicas',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.5,
                          letterSpacing: -0.2,
                          color: _zanateBlack,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Los siguientes enlaces conducen a los sitios web institucionales externos de cada facultad:',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: _subtleText,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: USACConstants.facultades
                            .where((f) => f['id'] != 'todas')
                            .map(
                              (f) => ActionChip(
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                avatar: const Icon(
                                  PhosphorIconsRegular.arrowSquareOut,
                                  size: 15,
                                  color: _zanateBlack,
                                ),
                                label: Text(
                                  f['nombre'].toString(),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _zanateBlack,
                                  ),
                                ),
                                onPressed: () => UrlUtils.openUrl(
                                  context,
                                  f['sitio'].toString(),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleTile({
    required String number,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _zanateBlack,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: _zanateBlack,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: _subtleText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalBullet({
    required String boldPrefix,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _zanateBlack,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: _subtleText,
              ),
              children: [
                TextSpan(
                  text: boldPrefix,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _zanateBlack,
                  ),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
