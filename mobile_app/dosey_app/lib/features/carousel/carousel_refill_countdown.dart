part of 'carousel_screen.dart';

class _RefillCountdownCard extends StatelessWidget {
  const _RefillCountdownCard({required this.slots});

  final List<CarouselSlot> slots;

  @override
  Widget build(BuildContext context) {
    final remaining = slots
        .where(
          (slot) =>
              slot.status == CarouselSlotStatus.assigned ||
              slot.status == CarouselSlotStatus.loaded,
        )
        .length;
    final dispensed = slots
        .where((slot) => slot.status == CarouselSlotStatus.dispensed)
        .toList();
    final needsReview = slots
        .where((slot) => slot.status == CarouselSlotStatus.needsReview)
        .length;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final warning = _warningFor(remaining, slots.isEmpty);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.inventory_2_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refill countdown',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _doseCountLabel(remaining),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dosey counts assigned or loaded slots as remaining. Dispensed slots need refill review before reuse.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RefillStatusChip(
                  icon: warning.icon,
                  label: warning.label,
                  isWarning: warning.isWarning,
                ),
                _RefillStatusChip(
                  icon: Icons.outbox_outlined,
                  label: _dispensedCountLabel(dispensed.length),
                ),
                _RefillStatusChip(
                  icon: Icons.fact_check_outlined,
                  label: '$needsReview needs review',
                ),
              ],
            ),
            if (dispensed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _markDispensedForReview(context, dispensed),
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  label: const Text('Review dispensed slots'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markDispensedForReview(
    BuildContext context,
    List<CarouselSlot> dispensed,
  ) async {
    try {
      // Bulk review is only a refill-state cleanup; dose outcomes are still
      // resolved through Today or Robot Face terminal actions.
      final dependencies = DoseyAppScope.of(context);
      for (final slot in dispensed) {
        await dependencies.carouselSlots.markNeedsReview(slot.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispensed slots marked for refill review.'),
        ),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  static _RefillWarning _warningFor(int remaining, bool hasNoSlots) {
    if (hasNoSlots) {
      return const _RefillWarning(
        label: 'No doses loaded yet',
        icon: Icons.inventory_2_outlined,
        isWarning: true,
      );
    }
    if (remaining == 0) {
      return const _RefillWarning(
        label: 'Carousel empty',
        icon: Icons.error_outline,
        isWarning: true,
      );
    }
    if (remaining <= 3) {
      return const _RefillWarning(
        label: 'Refill soon',
        icon: Icons.warning_amber_outlined,
        isWarning: true,
      );
    }
    return const _RefillWarning(
      label: 'Refill on track',
      icon: Icons.check_circle_outline,
    );
  }

  static String _doseCountLabel(int count) {
    return count == 1 ? '1 dose remaining' : '$count doses remaining';
  }

  static String _dispensedCountLabel(int count) {
    return count == 1 ? '1 slot dispensed' : '$count slots dispensed';
  }
}

class _RefillWarning {
  const _RefillWarning({
    required this.label,
    required this.icon,
    this.isWarning = false,
  });

  final String label;
  final IconData icon;
  final bool isWarning;
}

class _RefillStatusChip extends StatelessWidget {
  const _RefillStatusChip({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  final IconData icon;
  final String label;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isWarning
        ? colorScheme.onErrorContainer
        : colorScheme.onSurfaceVariant;
    final background = isWarning
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
