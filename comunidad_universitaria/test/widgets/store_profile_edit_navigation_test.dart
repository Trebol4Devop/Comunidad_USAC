import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/seller_profile.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/store_profile_screen.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  testWidgets(
    'Editar tienda en StoreProfileScreen navega a vista separada con AppBar y caretLeft',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const myStore = SellerProfile(
        publicId: 'seller-store-1',
        displayName: 'Emprendimiento USAC',
        businessName: 'Cafecito Ingeniería',
        businessDescription: 'Café y refacciones frente al T-3',
        isMyStore: true,
        isVerified: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const StoreProfileScreen(
            sellerPublicId: 'seller-store-1',
            initialProfile: myStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editButton = find.byTooltip('Editar tienda');
      expect(editButton, findsOneWidget);

      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.text('Editar Perfil Comercial'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsBold.caretLeft), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Guardar Cambios'), findsOneWidget);
    },
  );
}
