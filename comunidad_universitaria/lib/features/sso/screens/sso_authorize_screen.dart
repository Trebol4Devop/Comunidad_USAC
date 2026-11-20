import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../shared/widgets/zanate_ui.dart';
import '../sso_security_validator.dart';

class SsoAuthorizeScreen extends StatefulWidget {
  final String? clientId;
  final String? redirectUri;
  final String? state;
  final String activeAlias;
  final Function(String newAlias)? onAliasChanged;

  const SsoAuthorizeScreen({
    super.key,
    this.clientId,
    this.redirectUri,
    this.state,
    required this.activeAlias,
    this.onAliasChanged,
  });

  @override
  State<SsoAuthorizeScreen> createState() => _SsoAuthorizeScreenState();
}

class _SsoAuthorizeScreenState extends State<SsoAuthorizeScreen> {
  bool _isLoading = false;
  bool _isRedirecting = false;
  bool _waitingForGoogle = false;
  bool _googleAuthCompleted = false;
  StreamSubscription<AuthState>? _googleAuthSubscription;
  String? _redirectingUrl;
  String? _authErrorMessage;
  String? _infoMessage;

  String _currentAlias = '';

  @override
  void initState() {
    super.initState();
    _currentAlias = widget.activeAlias;
    _loadUserAlias();
  }

  @override
  void dispose() {
    unawaited(_googleAuthSubscription?.cancel());
    super.dispose();
  }

  Future<void> _loadUserAlias() async {
    final profile = await LocalStorageService.getUserProfile();
    if (mounted && profile.alias.isNotEmpty) {
      setState(() {
        _currentAlias = profile.alias;
      });
    }
  }

  bool get _isClientValid {
    final client = widget.clientId?.trim().toLowerCase();
    return client == 'pemtree';
  }

  bool get _isRedirectUriValid {
    if (widget.redirectUri == null || widget.redirectUri!.trim().isEmpty) {
      return true; // En desarrollo local sin parámetro explícito, usa el local por defecto
    }
    return SsoSecurityValidator.isValidRedirectUri(widget.redirectUri);
  }

  bool get _isAuthenticated {
    // If Supabase is configured, check authenticated user
    if (SupabaseConfig.isConfigured) {
      return SupabaseService.isAuthenticated;
    }
    // If running in offline / dev mode without live Supabase, allow local test session
    return true;
  }

  void _handleGoogleAuthState(AuthState state) {
    if (_googleAuthCompleted ||
        state.event != AuthChangeEvent.signedIn ||
        state.session?.user.isAnonymous != false) {
      return;
    }

    _googleAuthCompleted = true;
    unawaited(_googleAuthSubscription?.cancel());
    _googleAuthSubscription = null;
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _waitingForGoogle = false;
    });
    _loadUserAlias();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _waitingForGoogle = false;
      _googleAuthCompleted = false;
      _authErrorMessage = null;
      _infoMessage = null;
    });

    await _googleAuthSubscription?.cancel();
    _googleAuthSubscription = SupabaseService.client.auth.onAuthStateChange
        .listen(_handleGoogleAuthState);

    try {
      final currentUrl = SupabaseService.oauthRedirectUrl;
      final launched = await SupabaseService.signInWithGoogle(redirectTo: currentUrl);
      if (!launched) {
        throw StateError('No se pudo iniciar el acceso con Google.');
      }
      if (mounted && !_googleAuthCompleted) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = true;
        });
      }
    } catch (e) {
      await _googleAuthSubscription?.cancel();
      _googleAuthSubscription = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = false;
          _authErrorMessage = 'Error al conectar con Google: $e';
        });
      }
    }
  }

  String get _effectiveRedirectUri {
    final raw = widget.redirectUri?.trim();
    if (raw == null || raw.isEmpty) {
      return SsoSecurityValidator.defaultLocalRedirectUri;
    }

    // Si estamos en entorno web local (localhost) y el redirect_uri enviado apunta a Netlify/nube de PEMTREE,
    // garantizamos redirigir al PEMTREE local http://localhost:5173/auth/callback
    final isLocalWeb = kIsWeb && (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1');
    if (isLocalWeb && (raw.contains('netlify.app') || raw.contains('pemtree.'))) {
      return SsoSecurityValidator.defaultLocalRedirectUri;
    }

    return raw;
  }

  Future<void> _handleAuthorize() async {
    setState(() {
      _isLoading = true;
    });

    String accessToken = '';
    String refreshToken = '';
    int? expiresIn;

    if (SupabaseConfig.isConfigured) {
      try {
        final session = SupabaseConfig.client.auth.currentSession;
        if (session != null) {
          accessToken = session.accessToken;
          refreshToken = session.refreshToken ?? '';
          expiresIn = session.expiresIn;
        }
      } catch (e) {
        debugPrint('Error obteniendo sesión de Supabase: $e');
      }
    }

    // Fallback for local mock testing
    if (accessToken.isEmpty) {
      if (SupabaseConfig.isConfigured) {
        setState(() {
          _isLoading = false;
          _authErrorMessage =
              'Tu sesión no está activa. Inicia sesión de nuevo para autorizar el acceso.';
        });
        return;
      }

      // Sin Supabase configurado solo se permite el mock en depuración local.
      if (!kDebugMode) {
        setState(() {
          _isLoading = false;
          _authErrorMessage = 'Supabase no está configurado en esta compilación.';
        });
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      accessToken = 'mock_sso_access_token_$timestamp';
      refreshToken = 'mock_sso_refresh_token_$timestamp';
      expiresIn = 3600;
    }

    final targetUrl = SsoSecurityValidator.buildSuccessRedirectUrl(
      redirectUri: _effectiveRedirectUri,
      accessToken: accessToken,
      refreshToken: refreshToken,
      state: widget.state,
      expiresIn: expiresIn,
    );

    setState(() {
      _isLoading = false;
      _isRedirecting = true;
      _redirectingUrl = targetUrl;
    });

    await _performRedirect(targetUrl);
  }

  Future<void> _handleCancel() async {
    setState(() {
      _isLoading = true;
    });

    final targetUrl = SsoSecurityValidator.buildCancelRedirectUrl(
      redirectUri: _effectiveRedirectUri,
      state: widget.state,
      error: 'access_denied',
      errorDescription: 'El usuario canceló la autorización',
    );

    setState(() {
      _isLoading = false;
      _isRedirecting = true;
      _redirectingUrl = targetUrl;
    });

    await _performRedirect(targetUrl);
  }

  Future<void> _performRedirect(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: '_self',
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error al redirigir a PEMTREE: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ZanateColors.bg(isDark),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _buildBody(theme, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
    // 1. Check Redirect URI security whitelist
    if (!_isRedirectUriValid) {
      return _buildSecurityErrorCard(
        theme: theme,
        isDark: isDark,
        title: 'URL de Redirección No Autorizada',
        description:
            'La dirección de retorno solicitada no pertenece a la lista de orígenes permitidos por Comunidad USAC para PEMTREE.',
        recommendation:
            'En desarrollo local utiliza exactamente http://localhost:5173/auth/callback',
      );
    }

    // 2. Check Client ID validity
    if (!_isClientValid) {
      return _buildSecurityErrorCard(
        theme: theme,
        isDark: isDark,
        title: 'Cliente SSO Desconocido',
        description:
            'El parámetro client_id "${widget.clientId ?? 'no especificado'}" no está registrado en el servicio de autorización centralizada.',
        recommendation: 'Verifica que la aplicación cliente envíe client_id=pemtree.',
      );
    }

    // 3. If redirecting in progress
    if (_isRedirecting) {
      return _buildRedirectingCard(theme, isDark);
    }

    // 4. If user not authenticated, show login form first
    if (!_isAuthenticated) {
      return _buildLoginCard(theme, isDark);
    }

    // 5. Consent Screen
    return _buildConsentCard(theme, isDark);
  }

  Widget _buildSecurityErrorCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String description,
    required String recommendation,
  }) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.shade400.withValues(alpha: isDark ? 0.55 : 0.7),
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.red.shade900.withValues(alpha: 0.28)
                  : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIconsFill.shieldWarning,
              size: 46,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ZanateAccentBar(color: Colors.red.shade500),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZanateColors.surface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ZanateColors.border(isDark)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PhosphorIconsRegular.shieldCheck,
                  size: 18,
                  color: textPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZanateColors.ctaBg(isDark),
              foregroundColor: ZanateColors.ctaFg(isDark),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(PhosphorIconsRegular.house, size: 18),
            label: const Text(
              'Ir a Zanate',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard(ThemeData theme, bool isDark) {
    final userEmail = SupabaseService.currentUser?.email ?? 'usuario@estudiante.usac.edu.gt';
    final userAlias = _currentAlias.isNotEmpty ? _currentAlias : 'Estudiante USAC';
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Connected Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Zanate Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateBlack,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? ZanateColors.zanateEyeYellow : borderColor,
                  ),
                ),
                child: const Icon(
                  PhosphorIconsBold.bird,
                  color: ZanateColors.zanateEyeYellow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                PhosphorIconsRegular.arrowsLeftRight,
                size: 20,
                color: textMuted,
              ),
              const SizedBox(width: 14),
              // PEMTREE Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  PhosphorIconsBold.tree,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Title
          Text(
            'Conectar con PEMTREE',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 21,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: ZanateAccentBar()),
          const SizedBox(height: 8),

          // Friendly message required
          Text(
            'PEMTREE solicita autorización para consultar tu perfil de estudiante y permitirte calificar secciones.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.4,
              color: textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // User Active Identity Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZanateColors.surface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: ZanateColors.zanateBlack,
                  child: Text(
                    userAlias.isNotEmpty ? userAlias.characters.first.toUpperCase() : 'U',
                    style: const TextStyle(
                      color: ZanateColors.zanateEyeYellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userAlias,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            PhosphorIconsFill.sealCheck,
                            size: 15,
                            color: isDark
                                ? ZanateColors.zanateEyeYellow
                                : ZanateColors.zanateBlack,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Permissions summary list
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZanateColors.surface(isDark),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permisos que concederás a PEMTREE:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPermissionRow(
                  PhosphorIconsRegular.userCircle,
                  'Ver tu identificador y alias estudiantil verificado',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildPermissionRow(
                  PhosphorIconsRegular.chatTeardropText,
                  'Emitir votos y evaluaciones de catedráticos y secciones',
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                _buildPermissionRow(
                  PhosphorIconsRegular.lockSimple,
                  'Inicio de sesión seguro para la plataforma',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              // Reject / Cancel
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFF87171)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleCancel,
                  child: const Text('Cancelar / Rechazar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 14),
              // Authorize / Continue
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZanateColors.ctaBg(isDark),
                    foregroundColor: ZanateColors.ctaFg(isDark),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleAuthorize,
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ZanateColors.ctaFg(isDark),
                          ),
                        )
                      : const Text('Autorizar / Continuar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Security Notice Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.lockSimple,
                size: 13,
                color: textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                'Conexión segura y autenticación protegida',
                style: TextStyle(fontSize: 10.5, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(
    IconData icon,
    String text, {
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark
              ? ZanateColors.zanateEyeYellow
              : ZanateColors.zanateBlack,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: ZanateColors.textSecondary(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(ThemeData theme, bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  PhosphorIconsFill.lockKey,
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Zanate SSO',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Inicia Sesión para Conectar con PEMTREE',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: ZanateAccentBar()),
          const SizedBox(height: 10),
          Text(
            'Ingresa con tu cuenta de Zanate para otorgar acceso a la aplicación cliente.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          if (_authErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFF87171).withValues(alpha: 0.45)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Text(
                _authErrorMessage!,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFB91C1C),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_infoMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZanateColors.zanateEyeYellow.withValues(
                  alpha: isDark ? 0.16 : 0.18,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                _infoMessage!,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Google Sign In
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZanateColors.ctaBg(isDark),
              foregroundColor: ZanateColors.ctaFg(isDark),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ZanateColors.ctaFg(isDark),
                    ),
                  )
                : const ZanateGoogleIcon(size: 20),
            label: Text(
              _isLoading ? 'Conectando...' : 'Continuar con Google',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
            onPressed: (_isLoading || _waitingForGoogle)
                ? null
                : _handleGoogleSignIn,
          ),
          if (_waitingForGoogle) ...[
            const SizedBox(height: 10),
            Text(
              'Completa el acceso en Google y regresa a Zanate.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textSecondary),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'El acceso se realiza de forma segura mediante tu cuenta de Google.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedirectingCard(ThemeData theme, bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZanateColors.border(isDark)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: ZanateColors.zanateEyeYellow,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Redirigiendo a PEMTREE...',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Conectando de forma segura con tu cuenta de estudiante...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: textSecondary),
          ),
          if (_redirectingUrl != null) ...[
            const SizedBox(height: 20),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? ZanateColors.zanateEyeYellow
                    : ZanateColors.zanateBlack,
              ),
              onPressed: () => _performRedirect(_redirectingUrl!),
              child: const Text('Si no eres redirigido automáticamente, haz clic aquí'),
            ),
          ],
        ],
      ),
    );
  }
}
