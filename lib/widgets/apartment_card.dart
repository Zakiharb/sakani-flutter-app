// D:\ttu_housing_app\lib\widgets\apartment_card.dart
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'package:ttu_housing_app/app_settings.dart';

class ApartmentCard extends StatelessWidget {
  final Apartment apartment;
  final void Function(String id) onToggleSave;
  final void Function(String id) onTap;

  final String? badgeText;

  const ApartmentCard({
    super.key,
    required this.apartment,
    required this.onToggleSave,
    required this.onTap,
    this.badgeText,
  });

  bool _isNetworkImage(String path) => path.startsWith('http');

  @override
  Widget build(BuildContext context) {
    final String title = tr(
      context,
      apartment.title,
      apartment.titleAr ?? apartment.title,
    );

    final String? firstImage = apartment.images.isNotEmpty
        ? apartment.images.first
        : null;

    return InkWell(
      onTap: () => onTap(apartment.id),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        margin: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: firstImage != null
                        ? (_isNetworkImage(firstImage)
                              ? Image.network(
                                  firstImage,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          size: 32,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Image.asset(firstImage, fit: BoxFit.cover))
                        : Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Center(
                              child: Icon(
                                Icons.home_rounded,
                                size: 32,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => onToggleSave(apartment.id),
                      icon: Icon(
                        apartment.saved
                            ? Icons.favorite
                            : Icons.favorite_border_rounded,
                        color: apartment.saved
                            ? Colors.red
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),

                if (badgeText != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${apartment.price.toStringAsFixed(0)} ${tr(context, "JD/mo", "د.أ/شهر")}',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.bed_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${apartment.rooms} ${apartment.rooms == 1 ? tr(context, "Room", "غرفة") : tr(context, "Rooms", "غرف")}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.bathtub_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${apartment.bathrooms} ${tr(context, "Bath", "حمام")}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chair_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        apartment.furnished
                            ? tr(context, 'Furnished', 'مفروشة')
                            : tr(context, 'Not furnished', 'غير مفروشة'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  Text(
                    '~${apartment.distance.toStringAsFixed(1)} ${tr(context, "km to TTU (straight-line)", "كم عن الجامعة (خط مستقيم)")}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
