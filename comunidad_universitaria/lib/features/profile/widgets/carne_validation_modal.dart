import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/user_profile.dart';
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

  bool _isSavingDraft = false;
  bool _consentChecked = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _carneController = TextEditingController(
      text: widget.currentProfile.carne ?? '',
    );
    _nameController = TextEditingController(
      text: widget.currentProfile.studentName ?? '',
    );
  }

  @override
  void dispose() {
    _carneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveDraftForRetry() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentChecked) {
      setState(() {
        _errorMessage = 'Debes autorizar el guardado local antes de continuar.';
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isSavingDraft = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final updated = widget.currentProfile.copyWith(
      carne: _carneController.text.trim(),
      studentName: _nameController.text.trim(),
      isCarneVerified: false,
    );

    try {
      await ProfileService.saveProfile(updated);
      if (!mounted) return;

      widget.onProfileUpdated(updated);
      setState(() {
        _isSavingDraft = false;
        _statusMessage =
            'Borrador guardado solo para esta sesión. No hay una fuente institucional conectada: no se consultó Registro y Estadística y tu condición estudiantil no está verificada. Podrás reintentar cuando la verificación auténtica esté disponible.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          _errorMessage =
              'No se pudo guardar el borrador. Tus campos siguen disponibles para reintentar.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = ZanateColors.textPrimary(isDark);
    final subtleColor = ZanateColors.textSecondary(isDark);
    final borderColor = ZanateColors.border(isDark);
    final fillColor = ZanateColors.surface(isDark);

    InputDecoration zanateInput({
      required String labelText,
      String? hintText,
      Widget? prefixIcon,
      String? counterText,
    }) {
      final inputBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      );
      final focusedBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: titleColor, width: 1.6),
      );
      final errorBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      );
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        counterText: counterText,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: subtleColor,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
        hintStyle: const TextStyle(fontSize: 13.5, color: ZanateColors.hintText),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      backgroundColor: ZanateColors.card(isDark),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ZanateColors.zanateEyeYellow.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIconsFill.info,
                          color: isDark
                              ? ZanateColors.zanateEyeYellow
                              : ZanateColors.zanateBlack,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Datos para verificación de carné',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: 16.5,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Sin fuente institucional conectada',
                              style: TextStyle(fontSize: 11.5, color: subtleColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          PhosphorIconsRegular.x,
                          size: 20,
                          color: titleColor,
                        ),
                        onPressed: _isSavingDraft
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Consentimiento explícito para guardar el borrador local
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow.withValues(
                        alpha: 0.14,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: ZanateColors.zanateEyeYellow.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            PhosphorIconsFill.shieldCheck,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consentimiento para guardar un borrador',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Al guardar, tu carné y nombre se conservarán en el almacenamiento local de esta app para reintentar. Actualmente no hay una fuente institucional conectada: no se hará ninguna consulta ni se confirmará tu condición estudiantil.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.38,
                                  color: subtleColor,
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
                    style: TextStyle(color: titleColor),
                    decoration: zanateInput(
                      labelText: 'Número de Carné Universitario',
                      hintText: 'Ej. 202100123',
                      prefixIcon: Icon(
                        PhosphorIconsRegular.identificationCard,
                        size: 20,
                        color: subtleColor,
                      ),
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
                    style: TextStyle(color: titleColor),
                    decoration: zanateInput(
                      labelText: 'Nombre completo para reintentar',
                      hintText: 'Ej. Juan José Pérez Gómez',
                      prefixIcon: Icon(
                        PhosphorIconsRegular.user,
                        size: 20,
                        color: subtleColor,
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 3) {
                        return 'Ingresa tu nombre completo.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Consent Checkbox
                  InkWell(
                    onTap: () {
                      setState(() {
                        _consentChecked = !_consentChecked;
                        _errorMessage = null;
                        _statusMessage = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _consentChecked,
                            activeColor: ZanateColors.ctaBg(isDark),
                            checkColor: ZanateColors.ctaFg(isDark),
                            onChanged: (val) {
                              setState(() {
                                _consentChecked = val ?? false;
                                _errorMessage = null;
                                _statusMessage = null;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              'Autorizo usar mi carné y nombre solo en esta sesión. No se guardan en el dispositivo y esto no verifica mi condición estudiantil.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: subtleColor,
                              ),
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
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: isDark
                              ? ZanateColors.zanateEyeYellow
                              : ZanateColors.zanateBlack,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Action Buttons
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: subtleColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSavingDraft
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSavingDraft ? null : _saveDraftForRetry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ZanateColors.ctaBg(isDark),
                            foregroundColor: ZanateColors.ctaFg(isDark),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isSavingDraft
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ZanateColors.ctaFg(isDark),
                                  ),
                                )
                              : const Icon(
                                  PhosphorIconsBold.floppyDisk,
                                  size: 18,
                                ),
                          label: Text(
                            _isSavingDraft
                                ? 'Guardando...'
                                : 'Guardar borrador',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
