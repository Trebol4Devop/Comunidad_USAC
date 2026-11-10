import 'package:flutter/material.dart';
import '../models/bathroom_tier_config.dart';

/// Distintivo visual para la escala semántica de sanitarios USAC.
class BathroomTierBadge extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final Map<String, int> tagsSummary;
  final bool compact;

  const BathroomTierBadge({
    super.key,
    required this.averageRating,
    this.totalReviews = 0,
    this.tagsSummary = const {},
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tier = BathroomTierConfig.resolve(averageRating);
    final tierColor = Color(tier.colorHex);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: tierColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tier.emoji, style: const TextStyle(fontSize: 14.0)),
            const SizedBox(width: 4.0),
            Text(
              tier.label,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: tierColor,
              ),
            ),
            if (averageRating > 0) ...[
              const SizedBox(width: 6.0),
              Text(
                '${averageRating.toStringAsFixed(1)} ★',
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  color: tierColor,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: tierColor.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tier.emoji, style: const TextStyle(fontSize: 22.0)),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.label,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                        color: tierColor,
                      ),
                    ),
                    Text(
                      tier.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (averageRating > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    '${averageRating.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                  ),
                ),
            ],
          ),
          if (tagsSummary.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            const Divider(height: 1.0),
            const SizedBox(height: 6.0),
            Wrap(
              spacing: 6.0,
              runSpacing: 4.0,
              children: tagsSummary.entries.map((entry) {
                final label = _getTagLabel(entry.key);
                return Chip(
                  label: Text(
                    '$label (${entry.value})',
                    style: const TextStyle(fontSize: 11.0),
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  side: BorderSide(color: Colors.grey.shade300),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getTagLabel(String key) {
    return switch (key) {
      'has_water' => '💧 Agua',
      'has_paper' => '🧻 Papel',
      'has_soap' => '🧼 Jabón',
      'door_locks' => '🔒 Pestillo',
      'is_clean' => '✨ Limpio',
      _ => key,
    };
  }
}
