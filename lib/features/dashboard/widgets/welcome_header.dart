import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'স্বাগতম, অ্যাডমিন 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'আজকের দোকানের বেচা-বিক্রি ও হিসাব নিচে দেওয়া হলো।',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Live Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF059669).withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  shape: BoxShape.circle,
                ),
              ).animate(
                onPlay: (controller) => controller.repeat(reverse: true),
              ).scaleXY(
                end: 1.3,
                duration: 1200.ms,
                curve: Curves.easeInOut,
              ),
              const SizedBox(width: 8),
              const Text(
                'বিক্রি চালু',
                style: TextStyle(
                  color: Color(0xFF059669),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.02, duration: 400.ms, curve: Curves.easeOut);
  }
}
