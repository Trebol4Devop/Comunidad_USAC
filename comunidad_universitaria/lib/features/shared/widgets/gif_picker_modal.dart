import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';

class GifItem {
  final String title;
  final String url;
  final String category;

  const GifItem({
    required this.title,
    required this.url,
    required this.category,
  });
}

class GifPickerModal extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;

  const GifPickerModal({super.key, required this.onGifSelected});

  static Future<void> show(
    BuildContext context, {
    required Function(String gifUrl) onGifSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZanateColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => GifPickerModal(onGifSelected: onGifSelected),
    );
  }

  @override
  State<GifPickerModal> createState() => _GifPickerModalState();
}

class _GifPickerModalState extends State<GifPickerModal> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'todas';

  static const List<Map<String, String>> categories = [
    {'id': 'todas', 'name': 'Populares'},
    {'id': 'estudiando', 'name': 'Estudiando'},
    {'id': 'examenes', 'name': 'Parciales'},
    {'id': 'celebracion', 'name': 'Aprobado'},
    {'id': 'f', 'name': 'Reacciones'},
    {'id': 'memes', 'name': 'Comunidad'},
  ];

  static const List<GifItem> _curatedGifs = [
    // Estudiando
    GifItem(
      title: 'Escribiendo rápido',
      url: 'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif',
      category: 'estudiando',
    ),
    GifItem(
      title: 'Mucho Café',
      url: 'https://media.giphy.com/media/hPTZgtzfRIB5Nfb5rL/giphy.gif',
      category: 'estudiando',
    ),
    GifItem(
      title: 'Programando sin parar',
      url: 'https://media.giphy.com/media/13HgwGsXF0aiGY/giphy.gif',
      category: 'estudiando',
    ),
    GifItem(
      title: 'Leyendo apuntes',
      url: 'https://media.giphy.com/media/NFA61GS9qKZ68/giphy.gif',
      category: 'estudiando',
    ),
    GifItem(
      title: 'Súper concentrado',
      url: 'https://media.giphy.com/media/WoWm8YzFQJg5i/giphy.gif',
      category: 'estudiando',
    ),

    // Exámenes / Parciales
    GifItem(
      title: 'Revisando notas',
      url: 'https://media.giphy.com/media/32mC2kXYWCsg0/giphy.gif',
      category: 'examenes',
    ),
    GifItem(
      title: 'Todo bajo control',
      url: 'https://media.giphy.com/media/9M5jK4GXmD5o1irGrF/giphy.gif',
      category: 'examenes',
    ),
    GifItem(
      title: 'Estrés de parcial',
      url: 'https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif',
      category: 'examenes',
    ),

    // Celebración
    GifItem(
      title: 'Bailando de felicidad',
      url: 'https://media.giphy.com/media/blSTtZehjAZ8I/giphy.gif',
      category: 'celebracion',
    ),
    GifItem(
      title: 'Victoria épica',
      url: 'https://media.giphy.com/media/Is1O1TWV0LEJi/giphy.gif',
      category: 'celebracion',
    ),
    GifItem(
      title: 'Fuegos artificiales',
      url: 'https://media.giphy.com/media/artj92V8o75VPL7AeQ/giphy.gif',
      category: 'celebracion',
    ),
    GifItem(
      title: 'Aplausos',
      url: 'https://media.giphy.com/media/nbvFVPiEiJH6JOGIok/giphy.gif',
      category: 'celebracion',
    ),
    GifItem(
      title: 'Brindis de aprobación',
      url: 'https://media.giphy.com/media/g9582DNuQppxC/giphy.gif',
      category: 'celebracion',
    ),
    GifItem(
      title: 'Éxito total',
      url: 'https://media.giphy.com/media/nXxOjZrbnbRxS/giphy.gif',
      category: 'celebracion',
    ),
    GifItem(
      title: 'Fiesta de fin de semestre',
      url: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
      category: 'celebracion',
    ),

    // F / Reacciones
    GifItem(
      title: 'F en el Chat',
      url: 'https://media.giphy.com/media/hStvd5LiWCFzYNyxR4/giphy.gif',
      category: 'f',
    ),
    GifItem(
      title: 'Llorando en la lluvia',
      url: 'https://media.giphy.com/media/7SF5scGB2AFrgsXP63/giphy.gif',
      category: 'f',
    ),
    GifItem(
      title: 'No puede ser',
      url: 'https://media.giphy.com/media/d2lcHJTG5Tscg/giphy.gif',
      category: 'f',
    ),
    GifItem(
      title: 'Facepalm',
      url: 'https://media.giphy.com/media/XsUtdIeJ0MWMo/giphy.gif',
      category: 'f',
    ),
    GifItem(
      title: 'Cansado tras desvelo',
      url: 'https://media.giphy.com/media/l0MYAs5E2oIDCq9So/giphy.gif',
      category: 'f',
    ),
    GifItem(
      title: 'Tristeza total',
      url: 'https://media.giphy.com/media/OPU6wzx8JrHna/giphy.gif',
      category: 'f',
    ),

    // Memes / Comunidad
    GifItem(
      title: 'Homero desapareciendo',
      url: 'https://media.giphy.com/media/jUwpNzg9IcyrK/giphy.gif',
      category: 'memes',
    ),
    GifItem(
      title: 'Gato bailando',
      url: 'https://media.giphy.com/media/GeimqsH0TLDt4tScGw/giphy.gif',
      category: 'memes',
    ),
    GifItem(
      title: 'Cerebro explotando',
      url: 'https://media.giphy.com/media/26ufdipQqU2lhNA4g/giphy.gif',
      category: 'memes',
    ),
    GifItem(
      title: 'Confundido Travolta',
      url: 'https://media.giphy.com/media/3o7aTskHEUdgCQAXde/giphy.gif',
      category: 'memes',
    ),
    GifItem(
      title: 'Todo está bien',
      url: 'https://media.giphy.com/media/QMHoU66sBXqqLqYvGO/giphy.gif',
      category: 'memes',
    ),
    GifItem(
      title: 'Comiendo palomitas',
      url: 'https://media.giphy.com/media/pUeXcg80cO8I8/giphy.gif',
      category: 'memes',
    ),
    GifItem(
      title: 'Pulgar arriba',
      url: 'https://media.giphy.com/media/111ebonMs90YLu/giphy.gif',
      category: 'memes',
    ),
  ];

  List<GifItem> get _filteredGifs {
    final q = _searchController.text.trim().toLowerCase();
    return _curatedGifs.where((gif) {
      final matchesCategory =
          _selectedCategory == 'todas' || gif.category == _selectedCategory;
      final matchesQuery =
          q.isEmpty ||
          gif.title.toLowerCase().contains(q) ||
          gif.category.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = MediaQuery.of(context).size.height * 0.75;

    final titleColor = ZanateColors.textPrimary(isDark);
    final subtleText = ZanateColors.textSecondary(isDark);
    final borderColor = ZanateColors.border(isDark);

    return Container(
      height: height,
      color: ZanateColors.card(isDark),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ZanateColors.zanateEyeYellow.withValues(
                          alpha: 0.22,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.gif,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Insertar GIF o Sticker',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        PhosphorIconsRegular.x,
                        size: 20,
                        color: titleColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 13.5, color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Buscar GIFs...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: ZanateColors.hintText,
                    ),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: subtleText,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              PhosphorIconsRegular.x,
                              size: 16,
                              color: subtleText,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: ZanateColors.surface(isDark),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: titleColor, width: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Categories Chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: categories.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                    cat['name']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? ZanateColors.zanateBlack
                          : ZanateColors.textSecondary(isDark),
                    ),
                  ),
                  selected: isSelected,
                  backgroundColor: ZanateColors.surface(isDark),
                  selectedColor: ZanateColors.zanateEyeYellow,
                  side: BorderSide(
                    color: isSelected ? ZanateColors.zanateBlack : borderColor,
                    width: isSelected ? 1.2 : 1.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat['id']!);
                  },
                );
              },
            ),
          ),
          Divider(height: 16, color: borderColor),

          // GIFs Grid
          Expanded(
            child: _filteredGifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.smileySad,
                          size: 48,
                          color: ZanateColors.textMuted(isDark),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No se encontraron GIFs',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: ZanateColors.textMuted(isDark),
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.3,
                        ),
                    itemCount: _filteredGifs.length,
                    itemBuilder: (ctx, i) {
                      final gif = _filteredGifs[i];
                      return InkWell(
                        onTap: () {
                          widget.onGifSelected(gif.url);
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                gif.url,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: isDark
                                        ? ZanateColors.darkSurfaceSubtle
                                        : Colors.grey.shade200,
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: isDark
                                      ? ZanateColors.darkSurface
                                      : Colors.grey.shade300,
                                  child: Center(
                                    child: Icon(
                                      PhosphorIconsRegular.imageBroken,
                                      color: ZanateColors.textMuted(isDark),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  color: Colors.black54,
                                  child: Text(
                                    gif.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
