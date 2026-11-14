import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../marketplace_theme.dart';
import '../widgets/marketplace_card.dart';
import 'product_detail_screen.dart';
import 'store_profile_screen.dart';

class SavedListingsScreen extends StatefulWidget {
  final List<MarketplaceItem>? initialItems;

  const SavedListingsScreen({
    super.key,
    this.initialItems,
  });

  @override
  State<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends State<SavedListingsScreen> {
  List<MarketplaceItem> _savedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _savedItems = widget.initialItems!;
      _isLoading = false;
    } else {
      _loadSavedItems();
    }
  }

  Future<void> _loadSavedItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await MarketplaceService.fetchBookmarkedListings();
      if (!mounted) return;
      setState(() {
        _savedItems = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleToggleBookmark(MarketplaceItem item) async {
    final previousItems = List<MarketplaceItem>.from(_savedItems);
    setState(() {
      _savedItems.removeWhere((i) => i.id == item.id);
    });

    try {
      final result = await MarketplaceService.toggleBookmark(item.id);
      if (!mounted) return;
      if (result) {
        // If it was somehow bookmarked back
        setState(() {
          _savedItems = previousItems;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eliminado de tus guardados'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedItems = previousItems;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar de guardados.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return MarketplaceTheme.wrap(
      context,
      Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Productos Guardados',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSavedItems,
              child: _savedItems.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: EmptyStateWidget(
                          icon: PhosphorIconsRegular.bookmarkSimple,
                          title: 'Aún no guardaste productos',
                          description:
                              'Explora el catálogo y presiona el ícono de marcador en cualquier publicación para guardarla aquí.',
                          buttonText: 'Explorar Marketplace',
                          onButtonPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 1100 : double.infinity),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${_savedItems.length} publicaciones guardadas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _savedItems.length,
                                separatorBuilder: (_, _) => const SizedBox.shrink(),
                                itemBuilder: (ctx, i) {
                                  final item = _savedItems[i];
                                  return MarketplaceCard(
                                    key: ValueKey('saved_${item.id}'),
                                    item: item.copyWith(isBookmarked: true),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailScreen(
                                            itemId: item.id,
                                            initialItem: item,
                                          ),
                                        ),
                                      );
                                    },
                                    onOpenStore: item.sellerPublicId != null
                                        ? () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => StoreProfileScreen(
                                                  sellerPublicId: item.sellerPublicId!,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    onToggleBookmark: () => _handleToggleBookmark(item),
                                    onUpvote: () {},
                                  );
                                },
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
      ),
    );
  }
}
