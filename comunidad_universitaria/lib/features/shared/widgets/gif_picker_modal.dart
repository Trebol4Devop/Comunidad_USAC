import 'package:flutter/material.dart';

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

  const GifPickerModal({
    super.key,
    required this.onGifSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(String gifUrl) onGifSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      title: 'Lofi Cat Estudiando',
      url: 'https://media.giphy.com/media/LmN8OYiY4m0X85al0A/giphy.gif',
      category: 'estudiando',
    ),
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
      title: 'Programando en C++',
      url: 'https://media.giphy.com/media/unQ3IJU2RG7DO/giphy.gif',
      category: 'estudiando',
    ),

    // Exámenes / Parciales
    GifItem(
      title: 'Pánico en el examen',
      url: 'https://media.giphy.com/media/1FMaabePDEUuk/giphy.gif',
      category: 'examenes',
    ),
    GifItem(
      title: 'Matemáticas calculando',
      url: 'https://media.giphy.com/media/4JVTF9fRVGUN52dAZQ/giphy.gif',
      category: 'examenes',
    ),
    GifItem(
      title: 'Revisando notas',
      url: 'https://media.giphy.com/media/32mC2kXYWCsg0/giphy.gif',
      category: 'examenes',
    ),
    GifItem(
      title: 'Todo bajo control (fuego)',
      url: 'https://media.giphy.com/media/9M5jK4GXmD5o1irGrF/giphy.gif',
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

    // F / Fracaso
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
      title: 'Dormir para olvidar',
      url: 'https://media.giphy.com/media/l46CtynlN82CuZFni/giphy.gif',
      category: 'f',
    ),

    // Memes
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
      url: 'https://media.giphy.com/media/g01ZnwjtvtuKNTILA2/giphy.gif',
      category: 'memes',
    ),
  ];

  List<GifItem> get _filteredGifs {
    final q = _searchController.text.trim().toLowerCase();
    return _curatedGifs.where((gif) {
      final matchesCategory = _selectedCategory == 'todas' || gif.category == _selectedCategory;
      final matchesQuery = q.isEmpty || gif.title.toLowerCase().contains(q) || gif.category.toLowerCase().contains(q);
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
    final height = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.gif_box_outlined, color: Color(0xFF004B87), size: 26),
                    const SizedBox(width: 8),
                    Text(
                      'Insertar GIF o Sticker',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar GIFs (ej. café, examen, llorar)...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              separatorBuilder: (ctx, idx) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  label: Text(cat['name']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF004B87).withValues(alpha: 0.15),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat['id']!);
                  },
                );
              },
            ),
          ),
          const Divider(height: 16),

          // GIFs Grid
          Expanded(
            child: _filteredGifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sentiment_dissatisfied, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('No se encontraron GIFs', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                    color: Colors.grey.shade200,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                },
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  color: Colors.black54,
                                  child: Text(
                                    gif.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
