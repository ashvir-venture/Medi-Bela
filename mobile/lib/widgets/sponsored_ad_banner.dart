import 'package:flutter/material.dart';

/// A sponsor-ready advertisement slot.
///
/// For now it is fed static text (see `adHeadline` / `adMessage` in
/// app_strings.dart). Later, a sponsor's copy, image and link can be passed
/// in here without touching the home screen layout.
class SponsoredAdBanner extends StatelessWidget {
  const SponsoredAdBanner({
    super.key,
    required this.tag,
    required this.title,
    required this.message,
    this.imageUrl,
    this.onTap,
  });

  /// Small label such as "Sponsored Ad".
  final String tag;
  final String title;
  final String message;

  /// Optional sponsor image (reserved for when the slot is sold).
  final String? imageUrl;

  /// Optional tap action, e.g. open the sponsor's link.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Semantics(
      container: true,
      label: '$tag. $title. $message',
      excludeSemantics: true,
      button: onTap != null,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: primary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary.withValues(alpha: 0.25)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          tag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(message, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.favorite_outline, color: primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
