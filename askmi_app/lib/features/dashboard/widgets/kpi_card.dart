import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animated_count.dart';

class KpiData {
  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final String caption;

  /// Numeric KPIs animate a count-up; [textValue] is for KPIs whose value
  /// is a name rather than a number (e.g. "Best Branch").
  final double? numericValue;
  final String? textValue;
  final String prefix;
  final int decimals;

  const KpiData({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.caption,
    this.numericValue,
    this.textValue,
    this.prefix = '',
    this.decimals = 0,
  });
}

/// One horizontally-scrolling KPI tile. Slides up + fades in on build,
/// staggered by [index], and lifts on tap.
class KpiCard extends StatefulWidget {
  final KpiData data;
  final int index;

  const KpiCard({super.key, required this.data, required this.index});

  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + widget.index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 168,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? 0.10 : 0.04),
                  blurRadius: _pressed ? 18 : 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        d.label.toUpperCase(),
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: AppColors.textGray,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: d.tint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(d.icon, size: 16, color: d.color),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (d.numericValue != null)
                  AnimatedCount(
                    value: d.numericValue!,
                    prefix: d.prefix,
                    decimals: d.decimals,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  )
                else
                  Text(
                    d.textValue ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  d.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}