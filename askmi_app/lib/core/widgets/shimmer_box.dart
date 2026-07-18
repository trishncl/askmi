import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Hand-rolled shimmer placeholder — a moving gradient behind a grey box.
/// Written directly rather than pulling in the `shimmer` package: it's
/// ~40 lines and avoids another dependency to keep version-compatible.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * _controller.value, 0),
              end: Alignment(1 - 2 * _controller.value, 0),
              colors: const [
                Color(0xFFEDF1F5),
                Color(0xFFF7FAFC),
                Color(0xFFEDF1F5),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton stand-in for a chart card while its stream is still loading.
class ShimmerChartCard extends StatelessWidget {
  final double height;
  const ShimmerChartCard({super.key, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 160, height: 18),
          const SizedBox(height: 8),
          const ShimmerBox(width: 100, height: 12),
          const SizedBox(height: 20),
          ShimmerBox(height: height - 90),
        ],
      ),
    );
  }
}