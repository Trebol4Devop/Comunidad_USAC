import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/create_listing_dialog.dart';
import '../helpers/fake_postgrest.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakePostgrestServer fakeServer;

  setUp(() async {
    await resetTestState(initialPrefs: {
      'usac_forum_alias': 'Zanate Sigiloso #99',
      'usac_student_name': 'Carlos Estudiante Real',
      'usac_student_carne': '202109876',
      'usac_carne_verified': true,
      'usac_contact_whatsapp': '50255551234',
    });

    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
    SupabaseService.debugUserId = '51000000-0000-0000-0000-000000000001';
  });

  tearDown(() async {
    await resetTestState();
  });

  testWidgets(
    'Anti-doxxing: CreateListingDialog envía siempre el alias anónimo y NUNCA el nombre real ni carné del perfil verificado',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Mock de status del vendedor
      fakeServer.on('POST', RegExp(r'.*get_my_marketplace_status.*'), (req) {
        return [
          {
            'can_publish': true,
            'reason': 'OK',
            'plan_id': 'free',
            'plan_name': 'Estudiante',
            'max_active_items': 3,
            'max_images_per_item': 2,
            'allow_video': false,
            'active_items': 0,
            'remaining_slots': 3,
            'seller_public_id': 'pub-seller-uuid-1',
            'seller_type': 'student',
            'verification_status': 'approved',
            'is_verified': true,
            'is_on_campus': false,
          }
        ];
      });

      Map<String, dynamic>? capturedPayload;

      // Mock de inserción en marketplace_items
      fakeServer.onPost('/rest/v1/marketplace_items', (req) {
        final decoded = jsonDecode(req.body) as Map<String, dynamic>;
        capturedPayload = decoded;

        return {
          'id': 'item-created-uuid-1234',
          'title': decoded['title'] ?? 'Título',
          'description': decoded['description'] ?? 'Descripción',
          'price': decoded['price'] ?? 10.0,
          'is_free': decoded['is_free'] ?? false,
          'category': decoded['category'] ?? 'otros_articulos',
          'facultad': decoded['facultad'] ?? '08',
          'sede': decoded['sede'] ?? 'central',
          'building_code': decoded['building_code'] ?? 'T-3',
          'location_detail': decoded['location_detail'] ?? '',
          'contact_whatsapp': decoded['contact_whatsapp'],
          'contact_telegram': decoded['contact_telegram'],
          'contact_instagram': decoded['contact_instagram'],
          'contact_messenger': decoded['contact_messenger'],
          'social_links': decoded['social_links'] ?? [],
          'image_urls': decoded['image_urls'] ?? [],
          'video_url': decoded['video_url'],
          'is_sponsored': false,
          'sponsor_badge_text': null,
          'author_alias': decoded['author_alias'],
          'upvotes': 0,
          'reported_count': 0,
          'moderation_status': 0,
          'status': 'available',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      MarketplaceItem? createdItem;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: CreateListingDialog(
              activeAlias: 'Zanate Sigiloso #99',
              onAliasChanged: (_) {},
              onListingCreated: (item) {
                createdItem = item;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ingresar título válido
      final titleField = find.widgetWithText(
        TextFormField,
        'Título del producto o servicio',
      );
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'Calculadora Científica HP 50g');

      // Ingresar descripción válida
      final descField = find.widgetWithText(
        TextFormField,
        'Descripción detallada',
      );
      expect(descField, findsOneWidget);
      await tester.enterText(
        descField,
        'Excelente estado para ingeniería civil o eléctrica.',
      );

      // Ingresar precio
      final priceField = find.widgetWithText(
        TextFormField,
        'Precio en Quetzales',
      );
      expect(priceField, findsOneWidget);
      await tester.enterText(priceField, '450.00');

      await tester.pumpAndSettle();

      // Encontrar y pulsar botón de publicar
      final publishBtn = find.text('Publicar Anuncio');
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Verificaciones críticas de anti-doxxing:
      expect(capturedPayload, isNotNull, reason: 'La petición de inserción debe haber sido capturada');

      // 1. author_alias enviado a MarketplaceService.createListing coincide con widget.activeAlias
      expect(
        capturedPayload!['author_alias'],
        'Zanate Sigiloso #99',
        reason: 'author_alias debe ser estrictamente el alias anónimo asignado',
      );

      // 2. NUNCA el nombre real ni el carné del perfil verificado
      expect(
        capturedPayload!['author_alias'],
        isNot('Carlos Estudiante Real'),
        reason: 'El alias nunca debe coincidir con el nombre real del estudiante',
      );
      expect(
        capturedPayload.toString().contains('Carlos Estudiante Real'),
        isFalse,
        reason: 'El payload de inserción no debe filtrar el nombre real bajo ninguna clave',
      );
      expect(
        capturedPayload.toString().contains('202109876'),
        isFalse,
        reason: 'El payload de inserción no debe filtrar el carné estudiantil',
      );

      // 3. El callback onListingCreated recibe el item con el alias anónimo
      expect(createdItem, isNotNull);
      expect(createdItem!.authorAlias, 'Zanate Sigiloso #99');
    },
  );
}
