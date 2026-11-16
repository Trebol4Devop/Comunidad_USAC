import 'package:flutter/material.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/utils/responsive.dart';
import '../state/verification_controller.dart';
import '../widgets/verification_gate.dart';
import 'document_verification_screen.dart';
import 'institutional_email_step.dart';

/// Modal / Pantalla principal del flujo de onboarding y verificación estudiantil USAC.
/// Presenta la elección entre Camino A (Correo Institucional) y Camino B (Documento con OCR).
class VerificationFlowScreen extends StatefulWidget {
  final VerificationController controller;

  const VerificationFlowScreen({
    super.key,
    required this.controller,
  });

  /// Muestra el flujo en modal bottom sheet para móviles o en diálogo para pantallas grandes.
  static Future<void> show(
    BuildContext context, {
    VerificationController? controller,
  }) {
    final effectiveController =
        controller ?? VerificationGate.maybeOf(context) ?? VerificationController();

    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => VerificationFlowScreen(controller: effectiveController),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
            child: VerificationFlowScreen(controller: effectiveController),
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
    _tabController = TabController(length: 2, vsync: this);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verificación Estudiantil USAC',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            child: TabBar(
              controller: _tabController,
              indicatorColor: ZanateColors.zanateAccent,
              labelColor: isDark ? Colors.white : ZanateColors.zanateAccent,
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              tabs: const [
                Tab(
                  icon: Icon(Icons.email_outlined, size: 20),
                  text: 'Camino A: Correo',
                ),
                Tab(
                  icon: Icon(Icons.document_scanner_outlined, size: 20),
                  text: 'Camino B: Documento',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          InstitutionalEmailStep(
            controller: widget.controller,
            onSelectDocumentPath: () => _tabController.animateTo(1),
            onSuccess: _onSuccess,
          ),
          DocumentVerificationScreen(
            controller: widget.controller,
            onSelectEmailPath: () => _tabController.animateTo(0),
            onSuccess: _onSuccess,
          ),
        ],
      ),
    );
  }
}
