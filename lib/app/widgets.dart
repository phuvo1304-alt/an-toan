import 'package:flutter/material.dart';

import 'theme.dart';

/// The kinds of inline message the app shows.
enum BannerKind { error, success, info }

/// One consistent inline message (error, success or info): tinted background,
/// icon and text, so a state is never shown by color alone.
class StatusBanner extends StatelessWidget {
  final String message;
  final BannerKind kind;

  const StatusBanner({super.key, required this.message, this.kind = BannerKind.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final risk = context.risk;
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      BannerKind.error => (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline),
      BannerKind.success => (risk.safeContainer, risk.safe, Icons.check_circle_outline),
      BannerKind.info => (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.info_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

/// A quiet placeholder for "nothing here yet" (no image picked, no reports...).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.lg, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small spinner for inside buttons. Takes the button's current icon color,
/// so it stays visible in the disabled (loading) state too.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: IconTheme.of(context).color,
      ),
    );
  }
}

/// Section heading used inside screens ("Red flags", "Report this number"...).
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
