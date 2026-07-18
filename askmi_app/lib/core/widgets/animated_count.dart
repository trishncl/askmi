import 'package:flutter/material.dart';

/// Counts up to [value] when it first appears (and re-animates from the
/// previous number whenever the value changes, e.g. after a branch filter
/// switch). Uses TweenAnimationBuilder so there's no controller to dispose.
class AnimatedCount extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final int decimals;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Text(
        '$prefix${v.toStringAsFixed(decimals)}',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}