import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/alias_badge_button.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AliasBadgeButton Tests', () {
    testWidgets('Renderiza alias, avatar y responde al tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: AliasBadgeButton(
                alias: 'Estudiante #777',
                onAliasChanged: (_) {},
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estudiante #777'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.manage_accounts_outlined), findsOneWidget);

      await tester.tap(find.byType(AliasBadgeButton));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
