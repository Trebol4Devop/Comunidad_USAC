import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
  static const _zanateBlack = Color(0xFF0B0D10);
  static const _subtleText = Color(0xFF475569);

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
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color iconColor = _zanateBlack,
    Color titleColor = _zanateBlack,
    Widget? trailing,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
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
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: _subtleText,
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

    const trailingCaret = Icon(
      PhosphorIconsBold.caretRight,
      size: 16,
      color: Color(0xFF94A3B8),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      PhosphorIconsBold.caretLeft,
                      size: 22,
                      color: _zanateBlack,
                    ),
                    tooltip: 'Regresar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Configuración',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _zanateBlack,
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
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        if (widget.onToggleTheme != null) ...[
                          _buildMenuItem(
                            icon: isDark
                                ? PhosphorIconsRegular.sun
                                : PhosphorIconsRegular.moon,
                            title: 'Tema oscuro',
                            subtitle: isDark ? 'Activado' : 'Desactivado',
                            trailing: Switch.adaptive(
                              value: isDark,
                              activeTrackColor: _zanateBlack,
                              activeThumbColor: Colors.white,
                              onChanged: (_) => widget.onToggleTheme?.call(),
                            ),
                            onTap: () => widget.onToggleTheme?.call(),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ],

                        _buildMenuItem(
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
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildMenuItem(
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
                              backgroundColor: _zanateBlack,
                              foregroundColor: Colors.white,
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
