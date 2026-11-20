import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/constants/zanate_colors.dart';
import 'package:comunidad_universitaria/features/groups/screens/groups_screen.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/marketplace_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/welcome_screen.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
import 'package:comunidad_universitaria/features/shared/screens/settings_screen.dart';
import 'package:comunidad_universitaria/features/sso/screens/sso_authorize_screen.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget wrapDark(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: child,
    );
  }

  void expectDarkScaffold(WidgetTester tester) {
    final scaffold = tester.widgetList<Scaffold>(find.byType(Scaffold)).first;
    expect(scaffold.backgroundColor, ZanateColors.darkBg);
    expect(scaffold.backgroundColor, isNot(Colors.white));
  }

  group('Dark Mode Smoke Tests', () {
    testWidgets('SettingsScreen usa darkBg en ThemeMode.dark', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          SettingsScreen(
            activeAlias: 'Estudiante USAC #101',
            onAliasChanged: (_) {},
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkScaffold(tester);
    });

    testWidgets('GroupsScreen usa darkBg en ThemeMode.dark', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          GroupsScreen(
            activeAlias: 'Estudiante USAC #102',
            onAliasChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkScaffold(tester);
    });

    testWidgets('MarketplaceScreen usa darkBg en ThemeMode.dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapDark(
          MarketplaceScreen(
            activeAlias: 'Vendedor #103',
            onAliasChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkScaffold(tester);
    });

    testWidgets('ProfileScreen usa darkBg en ThemeMode.dark', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          ProfileScreen(
            activeAlias: 'Estudiante USAC #104',
            onAliasChanged: (_) {},
            isDarkMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkScaffold(tester);
    });

    testWidgets('SsoAuthorizeScreen usa darkBg en ThemeMode.dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapDark(
          const SsoAuthorizeScreen(
            clientId: 'pemtree',
            redirectUri: 'http://localhost:5173/auth/callback',
            state: 'smoke_test_state',
            activeAlias: 'Estudiante USAC #105',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkScaffold(tester);
    });

    testWidgets('WelcomeScreen usa darkBg en ThemeMode.dark', (tester) async {
      await tester.pumpWidget(
        wrapDark(
          WelcomeScreen(
            onSignIn: () {},
            onCreateAccount: () {},
            onContinueAsGuest: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectDarkScaffold(tester);
    });
  });
}
