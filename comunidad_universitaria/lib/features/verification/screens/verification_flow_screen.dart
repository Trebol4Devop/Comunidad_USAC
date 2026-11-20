import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/utils/responsive.dart';
import '../state/verification_controller.dart';
import '../widgets/verification_gate.dart';
import 'institutional_email_step.dart';
import 'support_contact_screen.dart';

/// Modal / Pantalla principal del flujo de onboarding y verificación estudiantil USAC.
/// Presenta la verificación automática y el contacto con soporte como alternativa.
class VerificationFlowScreen extends StatefulWidget {
  final VerificationController controller;
  final int initialTab;

  const VerificationFlowScreen({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });

  /// Muestra el flujo en modal bottom sheet para móviles o en diálogo para pantallas grandes.
  static Future<void> show(
    BuildContext context, {
    VerificationController? controller,
    int initialTab = 0,
  }) {
    final effectiveController =
        controller ?? VerificationGate.maybeOf(context) ?? VerificationController();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        clipBehavior: Clip.antiAlias,
        backgroundColor: ZanateColors.bg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: ZanateColors.border(isDark)),
        ),
        builder: (ctx) => VerificationFlowScreen(
          controller: effectiveController,
          initialTab: initialTab,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          clipBehavior: Clip.antiAlias,
          backgroundColor: ZanateColors.bg(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: ZanateColors.border(isDark)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: VerificationFlowScreen(
              controller: effectiveController,
              initialTab: initialTab,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<VerificationFlowScreen> createState() => _VerificationFlowScreenState();
}

class _VerificationFlowScreenState extends State<VerificationFlowScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSuccess() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);

    return Scaffold(
      backgroundColor: ZanateColors.bg(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 12),
              decoration: BoxDecoration(
                color: ZanateColors.card(isDark),
                border: Border(
                  bottom: BorderSide(color: ZanateColors.border(isDark)),
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
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: ZanateColors.zanateEyeYellow,
                      indicatorWeight: 3,
                      dividerColor: Colors.transparent,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      labelColor: textPrimary,
                      unselectedLabelColor: ZanateColors.textMuted(isDark),
                      labelStyle: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(
                          icon: Icon(PhosphorIconsRegular.sealCheck, size: 18),
                          text: 'Verificación automática',
                        ),
                        Tab(
                          icon: Icon(PhosphorIconsRegular.headset, size: 18),
                          text: 'Contactar con soporte',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  InstitutionalEmailStep(
                    controller: widget.controller,
                    onSelectSupportPath: () => _tabController.animateTo(1),
                    onSuccess: _onSuccess,
                  ),
                  SupportContactScreen(
                    onSelectAutomaticPath: () => _tabController.animateTo(0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
