import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/seccion_review.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/reviews_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../legal/widgets/terms_consent_modal.dart';
import '../widgets/create_seccion_review_dialog.dart';

class SeccionReviewsScreen extends StatefulWidget {
  final Future<List<SeccionReview>> Function({
    String? cursoCodigo,
    String? seccion,
    String? semestre,
  })?
  loader;
  final Future<bool> Function(String reviewId)? upvoteHandler;
  final Future<SeccionReview?> Function({
    required String cursoCodigo,
    required String seccion,
    required bool recomienda,
    String? catedraticoNombre,
    int? dificultad,
    int? cargaTareas,
    String? comentario,
    String semestre,
  })?
  createReviewHandler;
  final Future<bool> Function(BuildContext context)? consentGate;
  final String? initialCursoCodigo;
  final String? initialSeccion;
  final String? initialSemestre;

  const SeccionReviewsScreen({
    super.key,
    this.loader,
    this.upvoteHandler,
    this.createReviewHandler,
    this.consentGate,
    this.initialCursoCodigo,
    this.initialSeccion,
    this.initialSemestre,
  });

  @override
  State<SeccionReviewsScreen> createState() => _SeccionReviewsScreenState();
}

class _SeccionReviewsScreenState extends State<SeccionReviewsScreen> {
  late final TextEditingController _cursoFilterController;
  late final TextEditingController _seccionFilterController;

  String? _selectedSemestre;
  List<SeccionReview> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Seguimiento de comentarios expandidos por ID de reseña
  final Set<String> _expandedComments = {};

  static const List<String> _semestresFiltro = [
    '1S-2026',
    '2S-2025',
    '1S-2025',
  ];

  @override
  void initState() {
    super.initState();
    _cursoFilterController = TextEditingController(
      text: widget.initialCursoCodigo ?? '',
    );
    _seccionFilterController = TextEditingController(
      text: widget.initialSeccion ?? '',
    );
    _selectedSemestre = widget.initialSemestre;
    _loadReviews();
  }

  @override
  void dispose() {
    _cursoFilterController.dispose();
    _seccionFilterController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loaderFn = widget.loader ?? ReviewsService.fetchReviews;
      final results = await loaderFn(
        cursoCodigo: _cursoFilterController.text.trim().isEmpty
            ? null
            : _cursoFilterController.text.trim(),
        seccion: _seccionFilterController.text.trim().isEmpty
            ? null
            : _seccionFilterController.text.trim(),
        semestre: _selectedSemestre,
      );

      if (mounted) {
        setState(() {
          _reviews = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar las reseñas: $e';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar reseñas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleUpvote(SeccionReview review) async {
    try {
      final upvoteFn = widget.upvoteHandler ?? ReviewsService.upvoteReview;
      final success = await upvoteFn(review.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '¡Voto registrado!' : 'Voto retirado'),
          duration: const Duration(seconds: 1),
        ),
      );

      await _loadReviews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar upvote: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleOpenCreateDialog() async {
    if (widget.consentGate != null) {
      final ok = await widget.consentGate!(context);
      if (!ok) return;
    } else if (SupabaseConfig.isConfigured && SupabaseService.isAuthenticated) {
      final accepted = await ProfileService.hasAcceptedTerms();
      if (!accepted) {
        if (!mounted) return;
        final consentOk = await TermsConsentModal.show(context);
        if (!consentOk) return;
      }
    }

    if (!mounted) return;

    final newReview = await CreateSeccionReviewDialog.show(
      context,
      initialCursoCodigo: _cursoFilterController.text.trim().isNotEmpty
          ? _cursoFilterController.text.trim()
          : null,
      initialSeccion: _seccionFilterController.text.trim().isNotEmpty
          ? _seccionFilterController.text.trim()
          : null,
      createReviewHandler: widget.createReviewHandler,
    );

    if (newReview != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reseña publicada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadReviews();
    }
  }

  void _clearFilters() {
    _cursoFilterController.clear();
    _seccionFilterController.clear();
    setState(() => _selectedSemestre = null);
    _loadReviews();
  }

  bool get _hasActiveFilters =>
      _cursoFilterController.text.trim().isNotEmpty ||
      _seccionFilterController.text.trim().isNotEmpty ||
      _selectedSemestre != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reseñas de Secciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar',
            onPressed: _loadReviews,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('nueva_reseña_fab'),
        onPressed: _handleOpenCreateDialog,
        icon: const Icon(Icons.rate_review),
        label: const Text('Nueva reseña'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: Column(
          children: [
            // Panel de filtros
            _buildFiltersSection(theme, isDark),

            // Lista de reseñas o estados alternativos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && _reviews.isEmpty
                  ? _buildErrorView()
                  : _reviews.isEmpty
                  ? _buildEmptyView(isDark)
                  : _buildReviewsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersSection(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232428) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Filtro Código de Curso
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    key: const Key('filtro_curso_codigo'),
                    controller: _cursoFilterController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Código o curso...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2B2D31)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _loadReviews(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filtro Sección
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    key: const Key('filtro_seccion'),
                    controller: _seccionFilterController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Sección',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2B2D31)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _loadReviews(),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón Aplicar
              IconButton.filledTonal(
                icon: const Icon(Icons.tune, size: 18),
                tooltip: 'Aplicar filtros',
                onPressed: _loadReviews,
              ),

              if (_hasActiveFilters) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: 'Limpiar filtros',
                  onPressed: _clearFilters,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Chips de Semestre
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: _selectedSemestre == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  selected: _selectedSemestre == null,
                  onSelected: (selected) {
                    if (selected && _selectedSemestre != null) {
                      setState(() => _selectedSemestre = null);
                      _loadReviews();
                    }
                  },
                  visualDensity: VisualDensity.compact,
                ),
                ..._semestresFiltro.map((sem) {
                  final isSelected = _selectedSemestre == sem;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(sem),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedSemestre = selected ? sem : null;
                        });
                        _loadReviews();
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay reseñas para este curso. ¡Sé el primero!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Comparte tu opinión sobre catedráticos, tareas y dificultad.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handleOpenCreateDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Escribir primera reseña'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Ocurrió un error inesperado',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReviews,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _reviews.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewCard(review, isDark);
      },
    );
  }

  Widget _buildReviewCard(SeccionReview review, bool isDark) {
    final theme = Theme.of(context);
    final isExpanded = _expandedComments.contains(review.id);
    final hasComment =
        review.comentario != null && review.comentario!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF2B2D31) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Curso + Sección y Badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${review.cursoCodigo} · Sección ${review.seccion}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.isMine) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Tú',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (review.catedraticoNombre != null &&
                          review.catedraticoNombre!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                review.catedraticoNombre!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : const Color(0xFF334155),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chip de Recomienda
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: review.recomienda
                        ? (isDark
                              ? Colors.green.shade900.withValues(alpha: 0.3)
                              : Colors.green.shade50)
                        : (isDark
                              ? Colors.red.shade900.withValues(alpha: 0.3)
                              : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: review.recomienda
                          ? Colors.green.shade400
                          : Colors.red.shade400,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        review.recomienda
                            ? Icons.thumb_up_alt_outlined
                            : Icons.thumb_down_alt_outlined,
                        size: 13,
                        color: review.recomienda
                            ? (isDark
                                  ? Colors.green.shade300
                                  : Colors.green.shade700)
                            : (isDark
                                  ? Colors.red.shade300
                                  : Colors.red.shade700),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        review.recomienda ? 'Recomienda' : 'No recomienda',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: review.recomienda
                              ? (isDark
                                    ? Colors.green.shade300
                                    : Colors.green.shade800)
                              : (isDark
                                    ? Colors.red.shade300
                                    : Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Semestre & Métricas de Dificultad / Carga
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Semestre
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1F22)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    review.semestre,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ),

                // Dificultad
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.fitness_center_outlined,
                      size: 13,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Dificultad: ${review.dificultad ?? '-'}/5',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    const SizedBox(width: 4),
                    _buildMetricDots(review.dificultad, Colors.amber),
                  ],
                ),

                // Carga de tareas
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.assignment_outlined,
                      size: 13,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Carga: ${review.cargaTareas ?? '-'}/5',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    const SizedBox(width: 4),
                    _buildMetricDots(review.cargaTareas, Colors.blueAccent),
                  ],
                ),
              ],
            ),

            // Comentario
            if (hasComment) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1F22)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.comentario!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark
                            ? Colors.grey.shade300
                            : const Color(0xFF1E293B),
                      ),
                      maxLines: isExpanded ? null : 3,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                    if (review.comentario!.length > 140) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedComments.remove(review.id);
                            } else {
                              _expandedComments.add(review.id);
                            }
                          });
                        },
                        child: Text(
                          isExpanded ? 'Ver menos' : 'Ver más',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Footer: Botón de Upvote con contador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  key: Key('upvote_button_${review.id}'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: Text(
                    '${review.upvotes}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  onPressed: () => _handleUpvote(review),
                ),
                Text(
                  _formatDate(review.createdAt),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricDots(int? value, Color activeColor) {
    if (value == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final active = index < value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.grey.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
