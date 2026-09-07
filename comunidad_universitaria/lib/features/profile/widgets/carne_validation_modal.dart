import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/profile_service.dart';

class CarneValidationModal extends StatefulWidget {
  final UserProfile currentProfile;
  final Function(UserProfile updatedProfile) onProfileUpdated;

  const CarneValidationModal({
    super.key,
    required this.currentProfile,
    required this.onProfileUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile currentProfile,
    required Function(UserProfile) onProfileUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CarneValidationModal(
        currentProfile: currentProfile,
        onProfileUpdated: onProfileUpdated,
      ),
    );
  }

  @override
  State<CarneValidationModal> createState() => _CarneValidationModalState();
}

class _CarneValidationModalState extends State<CarneValidationModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _carneController;
  late TextEditingController _nameController;

  bool _isSimulatingValidation = false;
  bool _consentChecked = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _carneController = TextEditingController(text: widget.currentProfile.carne ?? '');
    _nameController = TextEditingController(text: widget.currentProfile.studentName ?? '');
  }

  @override
  void dispose() {
    _carneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      setState(() {
        _errorMessage = 'Debes aceptar los términos de verificación informada.';
      });
      return;
    }

    setState(() {
      _isSimulatingValidation = true;
      _errorMessage = null;
    });

    try {
      // Simulación de latencia con Registro y Estadística USAC
      await Future.delayed(const Duration(milliseconds: 700));

      final carneText = _carneController.text.trim();
      final nameText = _nameController.text.trim();

      final updated = widget.currentProfile.copyWith(
        carne: carneText,
        studentName: nameText,
        isCarneVerified: true,
      );

      await ProfileService.saveProfile(updated);
      await LocalStorageService.saveUserProfile(updated);

      if (mounted) {
        widget.onProfileUpdated(updated);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Carné $carneText validado exitosamente como estudiante USAC.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSimulatingValidation = false;
          _errorMessage = 'Error validando carné: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with USAC Shield / Verification Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: Color(0xFF059669),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Validación Estudiantil con Carné',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Verificación institucional de confianza',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSimulatingValidation ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Consentimiento informado en un clic (Box destacado)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.privacy_tip_outlined, size: 18, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Consentimiento de Privacidad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Solo consultaremos tu nombre y estado activo en Registro y Estadística. Tus notas y datos personales privados nunca son leídos ni almacenados.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark ? Colors.grey.shade300 : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Carné Input
                TextFormField(
                  controller: _carneController,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Número de Carné Universitario',
                    hintText: 'Ej. 202100123',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa tu número de carné.';
                    }
                    if (val.trim().length < 6) {
                      return 'El carné debe tener al menos 6 dígitos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Nombre Oficial Input
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Completo (como aparece en Registro)',
                    hintText: 'Ej. Juan José Pérez Gómez',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Ingresa tu nombre completo oficial.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Consent Checkbox
                InkWell(
                  onTap: () {
                    setState(() => _consentChecked = !_consentChecked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: _consentChecked,
                          activeColor: const Color(0xFF059669),
                          onChanged: (val) {
                            setState(() => _consentChecked = val ?? false);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Entiendo que mi nombre real solo se mostrará en Marketplace como "Verificado" y no en el Foro Anónimo.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSimulatingValidation ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSimulatingValidation ? null : _validateAndSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isSimulatingValidation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _isSimulatingValidation ? 'Validando...' : 'Validar con Registro',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
