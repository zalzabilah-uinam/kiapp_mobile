import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Consistent platform chip used across the app.
/// Tap handler opsional — kalau null, chip tetap decorative.
class PlatformChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const PlatformChip(this.label, this.icon, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final decorative = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryLight),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );

    if (onTap == null) return decorative;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: decorative,
    );
  }
}
