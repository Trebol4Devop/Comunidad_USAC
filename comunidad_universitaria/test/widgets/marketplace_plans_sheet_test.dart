import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_plan.dart';
import 'package:comunidad_universitaria/core/models/marketplace_seller_status.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/marketplace_plans_sheet.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const testPlans = [
    MarketplacePlan(
      id: 'free',
      name: 'Estudiante',
      priceMonthly: 0.0,
      maxActiveItems: 3,
      maxImagesPerItem: 2,
      allowVideo: false,
      autoSponsorItems: false,
      hideCompetitorRelated: false,
      defaultBadgeText: 'Estudiante Verificado',
      features: [
        'Hasta 3 publicaciones activas',
        '2 imágenes por publicación',
        'Vigencia de 14 días',
      ],
    ),
    MarketplacePlan(
      id: 'pro_student',
      name: 'Emprendedor',
      priceMonthly: 25.0,
      maxActiveItems: 20,
      maxImagesPerItem: 6,
      allowVideo: true,
      autoSponsorItems: false,
      hideCompetitorRelated: false,
      defaultBadgeText: 'Emprendedor Verificado',
      features: [
        'Hasta 20 publicaciones activas',
        '6 imágenes + 1 video',
        'Check-in de presencia en campus',
      ],
    ),
    MarketplacePlan(
      id: 'business_local',
      name: 'Comercio',
      priceMonthly: 75.0,
      maxActiveItems: 0,
      maxImagesPerItem: 10,
      allowVideo: true,
      autoSponsorItems: true,
      hideCompetitorRelated: true,
      defaultBadgeText: 'Tienda / Local Oficial',
      features: [
        'Publicaciones ilimitadas',
        'Galería extendida + 1 video',
        'Carrusel superior y prioridad VIP',
      ],
    ),
  ];

  Widget buildTestWidget({
    List<MarketplacePlan>? plans,
    MarketplaceSellerStatus? status,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: MarketplacePlansSheet(
          initialPlans: plans ?? testPlans,
          initialStatus: status,
        ),
      ),
    );
  }

  group('MarketplacePlansSheet Tests', () {
    testWidgets('Renderiza los 3 planes con sus nombres, precios y características', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verifica los tres planes
      expect(find.text('Estudiante'), findsOneWidget);
      expect(find.text('Emprendedor'), findsOneWidget);
      expect(find.text('Comercio'), findsOneWidget);

      // Precios formateados
      expect(find.text('Q0'), findsOneWidget);
      expect(find.text('Q25.00'), findsOneWidget);
      expect(find.text('Q75.00'), findsOneWidget);

      // Características clave
      expect(find.text('Vigencia de 14 días'), findsOneWidget);
      expect(find.text('Check-in de presencia en campus'), findsOneWidget);
      expect(find.text('Publicaciones ilimitadas'), findsWidgets);

      // Nota obligatoria de no comisiones
      expect(
        find.textContaining('La plataforma no cobra comisiones por tus ventas'),
        findsOneWidget,
      );
    });

    testWidgets('Marca el plan actual del vendedor con un chip de Plan actual', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final currentStatus = MarketplaceSellerStatus(
        sellerType: 'pro_student',
        planId: 'pro_student',
        planName: 'Emprendedor',
        isVerified: true,
        canPublish: true,
        activeItems: 5,
        maxActiveItems: 20,
        maxImagesPerItem: 6,
        allowVideo: true,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isOnCampus: false,
        reason: '',
      );

      await tester.pumpWidget(buildTestWidget(status: currentStatus));
      await tester.pumpAndSettle();

      // Debe mostrar el chip y el botón indicando "Plan actual"
      expect(find.text('Plan actual'), findsNWidgets(2));

      // Y para los otros planes muestra el CTA correspondiente
      expect(find.text('Inicia sesión para solicitar'), findsNWidgets(2));
    });

    testWidgets('RN-MKT-04: Simulación de error en fetchPlans muestra estado de error con retry y NO muestra precios inventados (Q25/Q75)', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Caso 1: initialError explícito
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: MarketplacePlansSheet(
              initialError: 'No pudimos cargar los planes desde el servidor. Revisa tu conexión e inténtalo de nuevo.',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el mensaje de error y el botón de reintentar
      expect(
        find.text('No pudimos cargar los planes desde el servidor. Revisa tu conexión e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      // NO deben aparecer precios inventados ni tarjetas de plan
      expect(find.text('Q25.00'), findsNothing);
      expect(find.text('Q75.00'), findsNothing);
      expect(find.text('Q25'), findsNothing);
      expect(find.text('Q75'), findsNothing);
      expect(find.text('Emprendedor'), findsNothing);
      expect(find.text('Comercio'), findsNothing);
    });

    testWidgets('RN-MKT-04: Lista vacía de planes activa estado de error y no renderiza precios inventados', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Caso 2: initialPlans vacío
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: MarketplacePlansSheet(
              initialPlans: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar mensaje de error de carga vacía y botón de reintento
      expect(
        find.text('No pudimos cargar los planes. Revisa tu conexión e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      // Verificamos ausencia total de precios inventados
      expect(find.text('Q25.00'), findsNothing);
      expect(find.text('Q75.00'), findsNothing);
      expect(find.text('Q25'), findsNothing);
      expect(find.text('Q75'), findsNothing);
    });
  });
}
