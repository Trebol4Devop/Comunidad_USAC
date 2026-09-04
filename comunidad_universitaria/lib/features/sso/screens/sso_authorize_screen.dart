import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
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
  String? _redirectingUrl;
  String? _authErrorMessage;

  // Email/Password login controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;

  String _currentAlias = '';

  @override
  void initState() {
    super.initState();
    _currentAlias = widget.activeAlias;
    _loadUserAlias();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _authErrorMessage = null;
    });

    try {
      final currentUrl = kIsWeb ? Uri.base.toString() : null;
      final success = await SupabaseService.signInWithGoogle(redirectTo: currentUrl);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          _loadUserAlias();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _authErrorMessage = 'Error al conectar con Google: $e';
        });
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _authErrorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        await SupabaseService.signUp(email: email, password: password);
      } else {
        await SupabaseService.signInWithPassword(email: email, password: password);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        _loadUserAlias();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _authErrorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
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
      debugPrint('Error al redirigir a PEMTREE: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
            'La dirección de retorno solicitada (${widget.redirectUri ?? 'vacía'}) no pertenece a la lista de orígenes permitidos por Comunidad USAC para PEMTREE (Open Redirect Protection).',
        recommendation:
            'En desarrollo local usa exactamente http://localhost:5173/auth/callback (sin comodines ni asteriscos).',
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
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2541) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
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
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.gpp_bad_rounded, size: 48, color: Colors.red.shade700),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: const TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004B87),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.home, size: 18),
            label: const Text('Ir a Comunidad USAC'),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCard(ThemeData theme, bool isDark) {
    final userEmail = SupabaseService.currentUser?.email ?? 'usuario@estudiante.usac.edu.gt';
    final userAlias = _currentAlias.isNotEmpty ? _currentAlias : 'Estudiante USAC';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2541) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
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
              // Comunidad USAC Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF004B87),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.school, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Icon(Icons.sync_alt_rounded, size: 24, color: Colors.grey.shade400),
              const SizedBox(width: 14),
              // PEMTREE Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.park, color: Colors.white, size: 24),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'Conectar con PEMTREE',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),

          const SizedBox(height: 10),

          // Friendly message required
          Text(
            'PEMTREE solicita autorización para consultar tu perfil de estudiante y permitirte calificar secciones.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 22),

          // User Active Identity Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF004B87),
                  child: Text(
                    userAlias.isNotEmpty ? userAlias.characters.first.toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 14, color: Color(0xFF004B87)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Permissions summary list
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Permisos que concederás a PEMTREE:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),
                _buildPermissionRow(Icons.account_circle_outlined, 'Ver tu identificador y alias estudiantil verificado'),
                const SizedBox(height: 8),
                _buildPermissionRow(Icons.rate_review_outlined, 'Emitir votos y evaluaciones de catedráticos y secciones'),
                const SizedBox(height: 8),
                _buildPermissionRow(Icons.lock_outline, 'Inicio de sesión seguro para la plataforma'),
              ],
            ),
          ),

          const SizedBox(height: 26),

          // Action Buttons
          Row(
            children: [
              // Reject / Cancel
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFF87171)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: const Color(0xFF004B87),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleAuthorize,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Autorizar / Continuar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Security Notice Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'Conexión segura y autenticación protegida',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF004B87)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, height: 1.3),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2541) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
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
                    color: const Color(0xFF004B87).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_outline, color: Color(0xFF004B87), size: 24),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Comunidad USAC SSO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Inicia Sesión para Conectar con PEMTREE',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa con tu cuenta de Comunidad USAC para otorgar acceso a la aplicación cliente.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 20),

            if (_authErrorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _authErrorMessage!,
                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Google Sign In
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.g_mobiledata, size: 24, color: Color(0xFFEA4335)),
              label: const Text('Continuar con Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _isLoading ? null : _handleGoogleSignIn,
            ),

            const SizedBox(height: 14),

            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('o con correo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 14),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'tu_correo@ejemplo.com',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
                isDense: true,
              ),
              validator: (val) {
                if (val == null || !val.contains('@')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
                isDense: true,
              ),
              validator: (val) {
                if (val == null || val.length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004B87),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isLoading ? null : _handleEmailAuth,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _isSignUp ? 'Crear Cuenta y Continuar' : 'Iniciar Sesión y Continuar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
            ),

            const SizedBox(height: 8),

            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _authErrorMessage = null;
                      });
                    },
              child: Text(
                _isSignUp ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate aquí',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedirectingCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2541) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF004B87)),
          ),
          const SizedBox(height: 24),
          Text(
            'Redirigiendo a PEMTREE...',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Conectando de forma segura con tu cuenta de estudiante...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (_redirectingUrl != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => _performRedirect(_redirectingUrl!),
              child: const Text('Si no eres redirigido automáticamente, haz clic aquí'),
            ),
          ],
        ],
      ),
    );
  }
}
