import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/support_config.dart';
import 'package:comunidad_universitaria/features/verification/screens/support_contact_screen.dart';

void main() {
  testWidgets('genera un mailto con cuenta, motivo, detalle y carné', (
    tester,
  ) async {
    Uri? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportContactScreen(
            accountEmail: 'alumno@usac.edu.gt',
            launchEmail: (uri) async {
              captured = uri;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('alumno@usac.edu.gt'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('support_detail')),
      'El código OTP no llega a mi correo.',
    );
    await tester.enterText(
      find.byKey(const Key('support_carne')),
      '202012345',
    );
    await tester.tap(find.byKey(const Key('support_send')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.scheme, 'mailto');
    expect(captured!.path, SupportConfig.email);

    final subject = captured!.queryParameters['subject'] ?? '';
    final body = captured!.queryParameters['body'] ?? '';

    expect(subject, contains('Verificación automática'));
    expect(body, contains('alumno@usac.edu.gt'));
    expect(body, contains('202012345'));
    expect(body, contains('No puedo acceder con mi correo institucional'));
    expect(body, contains('El código OTP no llega a mi correo.'));
  });

  testWidgets('permite enviar sin carné y sin detalle', (tester) async {
    Uri? captured;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportContactScreen(
            accountEmail: 'alumno@usac.edu.gt',
            launchEmail: (uri) async {
              captured = uri;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('support_send')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    final body = captured!.queryParameters['body'] ?? '';
    expect(body, isNot(contains('Carné USAC')));
    expect(body, isNot(contains('Detalle:')));
  });

  testWidgets('bloquea carné opcional con formato inválido', (tester) async {
    var launches = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportContactScreen(
            accountEmail: 'alumno@usac.edu.gt',
            launchEmail: (uri) async {
              launches++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('support_carne')), '123');
    await tester.tap(find.byKey(const Key('support_send')));
    await tester.pumpAndSettle();

    expect(launches, 0);
    expect(find.text('El carné debe tener exactamente 9 dígitos.'), findsOneWidget);
  });
}
