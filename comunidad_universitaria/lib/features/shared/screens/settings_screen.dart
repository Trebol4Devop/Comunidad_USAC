import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../onboarding/screens/merchant_support_screen.dart';
import '../../onboarding/state/session_controller.dart';
import '../../profile/screens/profile_screen.dart';
import '../../rules/screens/rules_screen.dart';
import '../../verification/widgets/verification_gate.dart';
import '../widgets/auth_modal.dart';

class SettingsScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback? onToggleTheme;

  const SettingsScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.onToggleTheme,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    required Function(String newAlias) onAliasChanged,
    VoidCallback? onToggleTheme,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onToggleTheme: onToggleTheme,
        ),
      ),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _currentAlias;

  @override
  void initState() {
    super.initState();
    _currentAlias = widget.activeAlias;
  }

  void _handleAliasUpdated(String newAlias) {
    setState(() => _currentAlias = newAlias);
    widget.onAliasChanged(newAlias);
  }

  Widget _buildMenuItem({
    required bool isDark,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
  }) {
    final defaultFg = ZanateColors.textPrimary(isDark);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? defaultFg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? defaultFg,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: ZanateColors.textSecondary(isDark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthenticated = SupabaseService.isAuthenticated;
    final canRequestMerchant =
        isAuthenticated &&
        !(VerificationGate.maybeOf(context)?.isMerchantVerified ?? false);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final borderColor = ZanateColors.border(isDark);

    final trailingCaret = Icon(
      PhosphorIconsBold.caretRight,
      size: 16,
      color: ZanateColors.textMuted(isDark),
    );

    return Scaffold(
      backgroundColor: ZanateColors.bg(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: ZanateColors.card(isDark),
                border: Border(
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      PhosphorIconsBold.caretLeft,
                      size: 22,
                      color: textPrimary,
                    ),
                    tooltip: 'Regresar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Configuración',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMenuItem(
                          isDark: isDark,
                          icon: PhosphorIconsRegular.userCircle,
                          title: 'Mi Perfil y Preferencias',
                          subtitle: 'Alias actual: $_currentAlias',
                          trailing: trailingCaret,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  activeAlias: _currentAlias,
                                  onAliasChanged: _handleAliasUpdated,
                                  onToggleTheme: widget.onToggleTheme,
                                  isDarkMode: isDark,
                                ),
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: borderColor),

                        if (widget.onToggleTheme != null) ...[
                          _buildMenuItem(
                            isDark: isDark,
                            icon: isDark
                                ? PhosphorIconsRegular.sun
                                : PhosphorIconsRegular.moon,
                            title: 'Tema oscuro',
                            subtitle: isDark ? 'Activado' : 'Desactivado',
                            trailing: Switch.adaptive(
                              value: isDark,
                              activeTrackColor: ZanateColors.ctaBg(isDark),
                              activeThumbColor: ZanateColors.ctaFg(isDark),
                              onChanged: (_) => widget.onToggleTheme?.call(),
                            ),
                            onTap: () => widget.onToggleTheme?.call(),
                          ),
                          Divider(height: 1, color: borderColor),
                        ],

                        _buildMenuItem(
                          isDark: isDark,
                          icon: PhosphorIconsRegular.shieldCheck,
                          title: 'Normas Comunitarias y Descargo',
                          trailing: trailingCaret,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RulesScreen(),
                              ),
                            );
                          },
                        ),

                        if (canRequestMerchant) ...[
                          Divider(height: 1, color: borderColor),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: PhosphorIconsRegular.storefront,
                            title: 'Quiero vender',
                            subtitle:
                                'Contacta con soporte para registrar tu negocio.',
                            trailing: trailingCaret,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MerchantSupportScreen(),
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        if (isAuthenticated)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () async {
                              final sessionCtrl =
                                  SessionController.maybeOf(context);
                              if (sessionCtrl != null) {
                                await sessionCtrl.signOut();
                              } else {
                                await LocalStorageService.setGuestMode(false);
                                await SupabaseService.signOut();
                              }
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sesión cerrada correctamente',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              PhosphorIconsBold.signOut,
                              size: 19,
                            ),
                            label: const Text(
                              'Cerrar Sesión',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZanateColors.ctaBg(isDark),
                              foregroundColor: ZanateColors.ctaFg(isDark),
                              elevation: 0,
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              AuthModal.show(
                                context,
                                title: 'Iniciar Sesión',
                                subtitle:
                                    'Accede para sincronizar tu perfil y favoritos.',
                                onAuthenticated: () {
                                  if (mounted) setState(() {});
                                },
                              );
                            },
                            icon: const Icon(PhosphorIconsBold.signIn, size: 19),
                            label: const Text(
                              'Iniciar Sesión / Registrarse',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
