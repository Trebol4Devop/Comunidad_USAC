import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/widgets/alias_modal.dart';
import '../../rules/screens/rules_screen.dart';
import 'auth_modal.dart';

class SettingsBottomSheet {
  static void show(
    BuildContext context, {
    required String activeAlias,
    required Function(String newAlias) onAliasChanged,
    VoidCallback? onToggleTheme,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: borderColor, width: 0.8),
      ),
      builder: (ctx) {
        final isAuthenticated = SupabaseService.isAuthenticated;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.gear,
                      size: 20,
                      color: ZanateColors.zanateAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configuración y Preferencias',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 1. User Profile & Preferences
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.userCircle,
                  size: 24,
                ),
                title: const Text(
                  'Mi Perfil y Preferencias',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('Alias actual: $activeAlias'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        activeAlias: activeAlias,
                        onAliasChanged: onAliasChanged,
                        onToggleTheme: onToggleTheme,
                        isDarkMode: isDark,
                      ),
                    ),
                  );
                },
              ),

              // 2. Change Alias directly
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.diceFive,
                  size: 24,
                ),
                title: const Text(
                  'Cambiar Alias Estudiantil',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Genera un nuevo alias anónimo para participar'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  AliasModal.show(
                    context,
                    currentAlias: activeAlias,
                    onSaved: onAliasChanged,
                  );
                },
              ),

              // 3. Theme Toggle
              if (onToggleTheme != null)
                ListTile(
                  leading: Icon(
                    isDark
                        ? PhosphorIconsRegular.sun
                        : PhosphorIconsRegular.moon,
                    size: 24,
                  ),
                  title: Text(
                    isDark ? 'Tema Claro' : 'Tema Oscuro',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onToggleTheme.call();
                  },
                ),

              // 4. Community Rules
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.shieldCheck,
                  size: 24,
                ),
                title: const Text(
                  'Normas Comunitarias y Descargo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RulesScreen()),
                  );
                },
              ),

              const Divider(height: 16),

              // 5. Auth: Login or Sign Out
              if (isAuthenticated)
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.signOut,
                    size: 24,
                    color: Color(0xFFEF4444),
                  ),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await SupabaseService.signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sesión cerrada correctamente')),
                      );
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(
                    PhosphorIconsRegular.signIn,
                    size: 24,
                    color: ZanateColors.zanateAccent,
                  ),
                  title: const Text(
                    'Iniciar Sesión / Registrarse',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ZanateColors.zanateAccent,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    AuthModal.show(
                      context,
                      title: 'Iniciar Sesión',
                      subtitle: 'Accede para sincronizar tu perfil y favoritos.',
                      onAuthenticated: () {},
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
