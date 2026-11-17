import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/support_config.dart';
import 'package:comunidad_universitaria/core/constants/categories.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/merchant_support_screen.dart';

void main() {
  testWidgets('genera un mailto con los datos del comercio', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Uri? captured;
    final category = USACConstants.marketplaceCategories
        .firstWhere((item) => item.id != 'todos');

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSupportScreen(
          accountEmail: 'dueno@correo.com',
          accountId: 'user-123',
          launchEmail: (uri) async {
            captured = uri;
            return true;
          },
        ),
      ),
    );

    expect(find.textContaining('dueno@correo.com'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('merchant_business_name')),
      'Cafetería El Sancarlista',
    );
    await tester.enterText(
      find.byKey(const Key('merchant_phone')),
      '+502 2345 6789',
    );
    await tester.enterText(
      find.byKey(const Key('merchant_location')),
      'Frente al edificio T-3',
    );
    await tester.enterText(
      find.byKey(const Key('merchant_description')),
      'Café, panadería y almuerzos.',
    );

    await tester.ensureVisible(find.byKey(const Key('merchant_send')));
    await tester.tap(find.byKey(const Key('merchant_send')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.scheme, 'mailto');
    expect(captured!.path, SupportConfig.email);

    final subject = captured!.queryParameters['subject'] ?? '';
    final body = captured!.queryParameters['body'] ?? '';

    expect(subject, contains('Alta de comercio'));
    expect(subject, contains('Cafetería El Sancarlista'));
    expect(body, contains('dueno@correo.com'));
    expect(body, contains('user-123'));
    expect(body, contains('Cafetería El Sancarlista'));
    expect(body, contains('23456789'));
    expect(body, contains('Frente al edificio T-3'));
    expect(body, contains(category.label));
    expect(body, contains('Café, panadería y almuerzos.'));
  });

  testWidgets('valida teléfono y ubicación obligatorios', (tester) async {
    var launches = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantSupportScreen(
          accountEmail: 'dueno@correo.com',
          launchEmail: (uri) async {
            launches++;
            return true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('merchant_business_name')),
      'Tienda',
    );
    await tester.enterText(
      find.byKey(const Key('merchant_phone')),
      '123',
    );

    await tester.ensureVisible(find.byKey(const Key('merchant_send')));
    await tester.tap(find.byKey(const Key('merchant_send')));
    await tester.pumpAndSettle();

    expect(launches, 0);
    expect(find.text('El teléfono debe tener 8 dígitos (Guatemala).'), findsOneWidget);
    expect(find.text('Indica dónde está tu puesto o local.'), findsOneWidget);
  });
}
