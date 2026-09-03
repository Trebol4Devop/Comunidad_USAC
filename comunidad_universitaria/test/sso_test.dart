import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/sso/sso_security_validator.dart';
import 'package:comunidad_universitaria/features/sso/screens/sso_authorize_screen.dart';

void main() {
  group('SSO Security Validator - Open Redirect Protection', () {
    test('Permite localhost:5173 para desarrollo local de PEMTREE', () {
      expect(
        SsoSecurityValidator.isValidRedirectUri('http://localhost:5173/auth/callback'),
        isTrue,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('http://127.0.0.1:5173/callback'),
        isTrue,
      );
    });

    test('Permite dominios Netlify (*.netlify.app)', () {
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://pemtree.netlify.app/auth/callback'),
        isTrue,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://deploy-preview-42--pemtree.netlify.app/callback'),
        isTrue,
      );
    });

    test('Permite dominios oficiales de producción de PEMTREE', () {
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://pemtree.com/auth/callback'),
        isTrue,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://app.pemtree.com/auth/callback'),
        isTrue,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://pemtree.app/callback'),
        isTrue,
      );
    });

    test('Bloquea orígenes no autorizados o maliciosos (Open Redirect Attacks)', () {
      // Dominio atacante externo
      expect(
        SsoSecurityValidator.isValidRedirectUri('http://malicious-site.com/steal-token'),
        isFalse,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://evil.com/callback'),
        isFalse,
      );

      // Suplantación de subdominio
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://evil-netlify.app.attacker.com/callback'),
        isFalse,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://pemtree.com.fake.org/callback'),
        isFalse,
      );

      // Esquema inseguro para dominios remotos
      expect(
        SsoSecurityValidator.isValidRedirectUri('http://pemtree.com/callback'),
        isFalse,
      );

      // User info spoofing
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://localhost:5173@evil.com/callback'),
        isFalse,
      );

      // Wildcards o asteriscos (deben ser rechazados rotundamente)
      expect(
        SsoSecurityValidator.isValidRedirectUri('http://localhost:5173/**'),
        isFalse,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('http://localhost:5173/*'),
        isFalse,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('https://*.netlify.app/auth/callback'),
        isFalse,
      );

      // Esquemas peligrosos
      expect(
        SsoSecurityValidator.isValidRedirectUri('javascript:alert("hacked")'),
        isFalse,
      );
      expect(
        SsoSecurityValidator.isValidRedirectUri('data:text/html,<script>alert(1)</script>'),
        isFalse,
      );
    });

    test('Usa por defecto exactamente http://localhost:5173/auth/callback si redirect_uri es nula o vacía', () {
      expect(SsoSecurityValidator.isValidRedirectUri(null), isTrue);
      expect(SsoSecurityValidator.isValidRedirectUri(''), isTrue);

      final successUrl = SsoSecurityValidator.buildSuccessRedirectUrl(
        redirectUri: '',
        accessToken: 'tok_1',
        refreshToken: 'tok_2',
        state: 'st_3',
      );
      expect(successUrl.startsWith('http://localhost:5173/auth/callback#'), isTrue);
      expect(successUrl.contains('*'), isFalse);
    });
  });

  group('SSO Hash Fragment URL Builder', () {
    test('Construye URL de éxito con tokens en el fragmento hash (#) y preserva el state', () {
      final url = SsoSecurityValidator.buildSuccessRedirectUrl(
        redirectUri: 'http://localhost:5173/auth/callback',
        accessToken: 'access_tok_123',
        refreshToken: 'refresh_tok_456',
        state: 'csrf_state_xyz789',
        expiresIn: 3600,
      );

      final uri = Uri.parse(url);

      // No debe contener tokens en los query parameters
      expect(uri.queryParameters.containsKey('access_token'), isFalse);
      expect(uri.queryParameters.containsKey('refresh_token'), isFalse);

      // Debe contener fragmento hash
      expect(uri.fragment.isNotEmpty, isTrue);
      expect(uri.fragment.contains('access_token=access_tok_123'), isTrue);
      expect(uri.fragment.contains('refresh_token=refresh_tok_456'), isTrue);
      expect(uri.fragment.contains('state=csrf_state_xyz789'), isTrue);
      expect(uri.fragment.contains('token_type=bearer'), isTrue);
      expect(uri.fragment.contains('expires_in=3600'), isTrue);
    });

    test('Construye URL de cancelación con error_description en el hash (#) y preserva el state', () {
      final url = SsoSecurityValidator.buildCancelRedirectUrl(
        redirectUri: 'https://pemtree.netlify.app/auth/callback',
        state: 'csrf_state_abc',
        errorDescription: 'El usuario canceló la autorización',
      );

      final uri = Uri.parse(url);

      expect(uri.queryParameters.containsKey('error'), isFalse);
      expect(uri.fragment.contains('error=access_denied'), isTrue);
      expect(uri.fragment.contains('state=csrf_state_abc'), isTrue);
      expect(uri.fragment.contains('error_description='), isTrue);
    });
  });

  group('SsoAuthorizeScreen UI Tests', () {
    testWidgets('Muestra error de seguridad si el redirect_uri no está en whitelist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SsoAuthorizeScreen(
            clientId: 'pemtree',
            redirectUri: 'http://evil-site.com/callback',
            state: 'test_state',
            activeAlias: 'Estudiante USAC #100',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('URL de Redirección No Autorizada'), findsOneWidget);
      expect(find.text('Conectar con PEMTREE'), findsNothing);
      expect(find.text('Autorizar / Continuar'), findsNothing);
    });

    testWidgets('Muestra error si el client_id no es pemtree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SsoAuthorizeScreen(
            clientId: 'cliente_desconocido',
            redirectUri: 'http://localhost:5173/auth/callback',
            state: 'test_state',
            activeAlias: 'Estudiante USAC #100',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cliente SSO Desconocido'), findsOneWidget);
      expect(find.text('Conectar con PEMTREE'), findsNothing);
    });

    testWidgets('Renderiza pantalla de consentimiento con parámetros legítimos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SsoAuthorizeScreen(
            clientId: 'pemtree',
            redirectUri: 'http://localhost:5173/auth/callback',
            state: 'valid_csrf_state',
            activeAlias: 'Estudiante USAC #404',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Conectar con PEMTREE'), findsOneWidget);
      expect(
        find.text('PEMTREE solicita autorización para consultar tu perfil de estudiante y permitirte calificar secciones.'),
        findsOneWidget,
      );
      expect(find.text('Autorizar / Continuar'), findsOneWidget);
      expect(find.text('Cancelar / Rechazar'), findsOneWidget);
    });
  });
}
