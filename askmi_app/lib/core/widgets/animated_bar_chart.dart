import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Bar chart whose bars grow upward on first build. Tap a bar to reveal
/// its exact value.
class AnimatedBarChart extends StatefulWidget {
  final List<String> labels;
  final List<double> values;
  final String Function(double)? valueFormatter;

  const AnimatedBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.valueFormatter,
  });

  @override
  State<AnimatedBarChart> createState() => _AnimatedBarChartState();
}

class _AnimatedBarChartState extends State<AnimatedBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return const Center(
        child: Text('No data yet', style: TextStyle(color: AppColors.textGray)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onTapDown: (d) => _handleTap(d.localPosition, constraints.maxWidth),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _BarChartPainter(
              labels: widget.labels,
              values: widget.values,
              progress: Curves.easeOutBack.transform(_controller.value).clamp(0.0, 1.0),
              touchedIndex: _touchedIndex,
              valueFormatter: widget.valueFormatter ?? (v) => v.toStringAsFixed(0),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset pos, double width) {
    const leftPad = 42.0;
    const rightPad = 12.0;
    final chartW = width - leftPad - rightPad;
    final slot = chartW / widget.values.length;
    final index = ((pos.dx - leftPad) / slot).floor();
    setState(() {
      _touchedIndex =
          (index >= 0 && index < widget.values.length && _touchedIndex != index) ? index : null;
    });
  }
}

class _BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final double progress;
  final int? touchedIndex;
  final String Function(double) valueFormatter;

  _BarChartPainter({
    required this.labels,
    required this.values,
    required this.progress,
    required this.touchedIndex,
    required this.valueFormatter,
  });

  static const _leftPad = 42.0;
  static const _rightPad = 12.0;
  static const _topPad = 14.0;
  static const _bottomPad = 30.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    final rawMax = values.reduce(math.max);
    final maxVal = rawMax <= 0 ? 1.0 : rawMax;

    final gridPaint = Paint()
      ..color = const Color(0xFFEDF1F5)
      ..strokeWidth = 1;
    const labelStyle = TextStyle(color: AppColors.textGray, fontSize: 10);

    for (int i = 0; i <= 4; i++) {
      final y = _topPad + chartH * i / 4;
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: valueFormatter(maxVal * (4 - i) / 4), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPad - tp.width - 6, y - tp.height / 2));
    }

    final slot = chartW / values.length;
    final barW = math.min(slot * 0.55, 44.0);

    for (int i = 0; i < values.length; i++) {
      final fullH = (values[i] / maxVal) * chartH;
      final h = fullH * progress;
      final cx = _leftPad + slot * i + slot / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, _topPad + chartH - h, barW, h),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      );

      final isTouched = touchedIndex == i;
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isTouched
                ? [AppColors.teal, AppColors.teal.withValues(alpha: 0.75)]
                : [AppColors.orange, AppColors.orange.withValues(alpha: 0.72)],
          ).createShader(rect.outerRect),
      );

      // Branch name under each bar, ellipsised to its slot.
      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: slot - 4);
        tp.paint(canvas, Offset(cx - tp.width / 2, size.height - _bottomPad + 8));
      }

      if (isTouched && progress > 0.9) {
        final tp = TextPainter(
          text: TextSpan(
            text: valueFormatter(values[i]),
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, _topPad + chartH - h - tp.height - 6));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.progress != progress || old.touchedIndex != touchedIndex || old.values != values;
}