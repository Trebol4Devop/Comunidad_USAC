import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Pantalla provisional de sitio en construcción.
///
/// Restricciones del entorno:
/// 1. La verificación en 2 pasos (TOTP / MFA) está deshabilitada en la app.
/// 2. Únicamente se permite el inicio de sesión con Google.
/// 3. El usuario solo ve esta pantalla y no tiene acceso a ninguna función interna.
class UnderConstructionScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const UnderConstructionScreen({
    super.key,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<UnderConstructionScreen> createState() =>
      _UnderConstructionScreenState();
}

class _UnderConstructionScreenState extends State<UnderConstructionScreen> {
  StreamSubscription<AuthState>? _authSubscription;
  User? _currentUser;
  bool _isLoading = false;
  bool _waitingForGoogle = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentUser = SupabaseService.currentUser;

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  void _handleAuthStateChange(AuthState state) {
    if (!mounted) return;

    final user = state.session?.user ?? SupabaseService.currentUser;
    final isAnon = user?.isAnonymous ?? true;

    setState(() {
      _currentUser = (!isAnon && user != null) ? user : null;
      if (_currentUser != null) {
        _waitingForGoogle = false;
        _isLoading = false;
        _errorMessage = null;
      } else if (state.event == AuthChangeEvent.signedOut) {
        _waitingForGoogle = false;
        _isLoading = false;
      }
    });
  }

  bool get _isAuthenticated =>
      _currentUser != null && !(_currentUser!.isAnonymous);

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _waitingForGoogle = false;
      _errorMessage = null;
    });

    try {
      final currentUrl = SupabaseService.oauthRedirectUrl;
      final launched = await SupabaseService.signInWithGoogle(
        redirectTo: currentUrl,
      );

      if (!launched) {
        throw StateError('No se pudo inicializar la conexión con Google.');
      }

      if (mounted && !_isAuthenticated) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = false;
          _errorMessage =
              'No se pudo conectar con Google. Por favor, inténtalo de nuevo.';
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signOut();
      if (mounted) {
        setState(() {
          _currentUser = null;
          _isLoading = false;
          _waitingForGoogle = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cerrar sesión: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final isMobile = Responsive.isMobile(context);

    final surfaceColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final scaffoldBg = isDark
        ? const Color(0xFF0F172A)
        : ZanateColors.surfaceBg;
    final textPrimary = isDark ? Colors.white : ZanateColors.zanateDark;
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior limpia
            _buildTopBar(
              isDark: isDark,
              borderColor: borderColor,
              surfaceColor: surfaceColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),

            // Contenido central: solo "Sitio en Construcción"
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.04,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(isMobile ? 24 : 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Ícono de Construcción
                          _buildConstructionIcon(isDark),

                          const SizedBox(height: 20),

                          // Título principal
                          Text(
                            'Sitio en Construcción',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Subtítulo
                          Text(
                            'Estamos trabajando para brindarte una mejor experiencia. Próximamente disponible para toda la comunidad.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
                              color: textSecondary,
                            ),
                          ),

                          const SizedBox(height: 24),
                          Divider(color: borderColor, height: 1),
                          const SizedBox(height: 24),

                          // Vista condicionada por estado de autenticación
                          if (_isAuthenticated)
                            _buildAuthenticatedView(
                              isDark: isDark,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            )
                          else
                            _buildUnauthenticatedView(
                              isDark: isDark,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pie de página institucional
            Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 8),
              child: Text(
                '© 2026 Zanate — Comunidad Zanate USAC',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 11.5, color: textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar({
    required bool isDark,
    required Color borderColor,
    required Color surfaceColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Marca institucional Zanate
          SizedBox(
            width: 34,
            height: 34,
            child: Image.asset(
              'assets/images/zanate_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                PhosphorIconsBold.graduationCap,
                color: ZanateColors.zanateAccent,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zanate',
                style: GoogleFonts.croissantOne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Text(
                'Comunidad Universitaria',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Botón de cambio de tema
          if (widget.onToggleTheme != null)
            IconButton(
              icon: PhosphorIcon(
                isDark ? PhosphorIconsRegular.sun : PhosphorIconsRegular.moon,
                size: 20,
                color: textSecondary,
              ),
              tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
              onPressed: widget.onToggleTheme,
            ),
        ],
      ),
    );
  }

  Widget _buildConstructionIcon(bool isDark) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
            : const Color(0xFFFFFBEB),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? const Color(0xFFB45309).withValues(alpha: 0.5)
              : const Color(0xFFFDE68A),
          width: 1.5,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.construction_rounded,
          size: 40,
          color: Color(0xFFD97706),
        ),
      ),
    );
  }

  /// Vista cuando el usuario NO ha iniciado sesión con Google
  Widget _buildUnauthenticatedView({
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.red.shade200 : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        if (_waitingForGoogle) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 10),
                Text(
                  'Completa el inicio de sesión en Google en la ventana abierta.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12.5, color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Botón único de Google
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            foregroundColor: textPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            side: BorderSide(color: borderColor, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: (_isLoading || _waitingForGoogle)
              ? null
              : _handleGoogleSignIn,
          child: _isLoading
              ? SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textPrimary,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsBold.googleLogo,
                      size: 22,
                      color: const Color(0xFFEA4335),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continuar con Google',
                      style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Vista cuando el usuario SÍ ha iniciado sesión con Google
  Widget _buildAuthenticatedView({
    required bool isDark,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final email = _currentUser?.email ?? 'Usuario de Google';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tarjeta simple de cuenta
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF065F46) : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sesión iniciada',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'La plataforma estará disponible próximamente.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
        ),

        const SizedBox(height: 24),

        // Botón para cerrar sesión
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.red.shade300 : Colors.red.shade700,
            side: BorderSide(
              color: isDark ? Colors.red.shade900 : Colors.red.shade200,
            ),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : PhosphorIcon(PhosphorIconsRegular.signOut, size: 20),
          label: Text(
            _isLoading ? 'Cerrando sesión...' : 'Cerrar sesión',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _isLoading ? null : _handleSignOut,
        ),
      ],
    );
  }
}
