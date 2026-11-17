/// Configuración del canal de soporte para la verificación de estudiantes.
///
/// La dirección se puede sobreescribir en build con:
/// `--dart-define=SUPPORT_EMAIL=otro@correo.com`
class SupportConfig {
  SupportConfig._();

  static const String email = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'trebol4devop@proton.me',
  );

  static const String subjectPrefix =
      'Soporte — Verificación automática Comunidad USAC';
}
