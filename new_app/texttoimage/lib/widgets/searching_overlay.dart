import 'dart:math' as math;

import 'package:flutter/material.dart';

class SearchingOverlay extends StatelessWidget {
  const SearchingOverlay({super.key, required this.visible, required this.label});

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          color: Colors.black.withValues(alpha: 0.40),
          child: Center(
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _SearchingSpinner(),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
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

class _SearchingSpinner extends StatefulWidget {
  const _SearchingSpinner();

  @override
  State<_SearchingSpinner> createState() => _SearchingSpinnerState();
}

class _SearchingSpinnerState extends State<_SearchingSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final a = _c.value * 2 * math.pi;
          return Transform.rotate(
            angle: a,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.12),
                    scheme.primary,
                    scheme.secondary,
                    scheme.primary.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
