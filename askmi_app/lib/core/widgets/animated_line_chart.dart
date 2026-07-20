import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Curved line chart with gradient fill that draws itself in on first
/// build, plus tap-to-inspect tooltips.
///
/// Hand-painted rather than using fl_chart: one less dependency whose API
/// shifts between major versions. Trade-off — pan/zoom and multi-series
/// aren't supported here. Neither is needed for a 7-point weekly trend.
class AnimatedLineChart extends StatefulWidget {
  final List<String> labels;
  final List<double> values;
  final String Function(double)? valueFormatter;

  const AnimatedLineChart({
    super.key,
    required this.labels,
    required this.values,
    this.valueFormatter,
  });

  @override
  State<AnimatedLineChart> createState() => _AnimatedLineChartState();
}

class _AnimatedLineChartState extends State<AnimatedLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
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
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _handleTap(details.localPosition, constraints.maxWidth),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _LineChartPainter(
                labels: widget.labels,
                values: widget.values,
                progress: Curves.easeOutCubic.transform(_controller.value),
                touchedIndex: _touchedIndex,
                valueFormatter: widget.valueFormatter ?? (v) => v.toStringAsFixed(0),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset position, double width) {
    const leftPad = 42.0;
    const rightPad = 12.0;
    final chartWidth = width - leftPad - rightPad;
    final step = chartWidth / math.max(1, widget.values.length - 1);
    final index = ((position.dx - leftPad) / step).round();
    setState(() {
      _touchedIndex =
          (index >= 0 && index < widget.values.length && _touchedIndex != index) ? index : null;
    });
  }
}

class _LineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final double progress;
  final int? touchedIndex;
  final String Function(double) valueFormatter;

  _LineChartPainter({
    required this.labels,
    required this.values,
    required this.progress,
    required this.touchedIndex,
    required this.valueFormatter,
  });

  static const _leftPad = 42.0;
  static const _rightPad = 12.0;
  static const _topPad = 14.0;
  static const _bottomPad = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _leftPad - _rightPad;
    final chartH = size.height - _topPad - _bottomPad;
    final rawMax = values.reduce(math.max);
    final maxVal = rawMax <= 0 ? 1.0 : rawMax;

    final gridPaint = Paint()
      ..color = const Color(0xFFEDF1F5)
      ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: AppColors.textGray, fontSize: 10);

    // Horizontal gridlines + y-axis labels
    for (int i = 0; i <= 4; i++) {
      final y = _topPad + chartH * i / 4;
      canvas.drawLine(Offset(_leftPad, y), Offset(size.width - _rightPad, y), gridPaint);
      final labelValue = maxVal * (4 - i) / 4;
      final tp = TextPainter(
        text: TextSpan(text: valueFormatter(labelValue), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_leftPad - tp.width - 6, y - tp.height / 2));
    }

    Offset pointAt(int i) {
      final x = _leftPad + chartW * i / math.max(1, values.length - 1);
      final y = _topPad + chartH - (values[i] / maxVal) * chartH;
      return Offset(x, y);
    }

    // Build a smooth curve through the points.
    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        final prev = pointAt(i - 1);
        final cx = (prev.dx + p.dx) / 2;
        linePath.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
      }
    }

    // Animate by revealing a fraction of the path's length.
    final metrics = linePath.computeMetrics().toList();
    final drawPath = Path();
    for (final m in metrics) {
      drawPath.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }

    // Gradient fill under the revealed portion. Only meaningful with 2+
    // points — with a single point (e.g. a "Today" trend with one bucket)
    // there's no line to spread a fill under, so skip it entirely rather
    // than let the old width-based formula draw a wedge across the whole
    // chart.
    if (progress > 0.02 && values.length > 1) {
      // Interpolate the fill's right edge from the actual point
      // positions (not raw chart width) so it always lines up with
      // where the line has actually been drawn to.
      final revealIndex = (progress * (values.length - 1)).clamp(0, values.length - 1);
      final lo = revealIndex.floor();
      final hi = revealIndex.ceil();
      final t = revealIndex - lo;
      final pLo = pointAt(lo);
      final pHi = pointAt(hi);
      final tipX = pLo.dx + (pHi.dx - pLo.dx) * t;

      final fillPath = Path.from(drawPath)
        ..lineTo(tipX, size.height - _bottomPad)
        ..lineTo(_leftPad, size.height - _bottomPad)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.teal.withValues(alpha: 0.28),
              AppColors.teal.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(_leftPad, _topPad, chartW, chartH)),
      );
    }

    if (values.length > 1) {
      canvas.drawPath(
        drawPath,
        Paint()
          ..color = AppColors.teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Dots + x labels, fading in as the line reaches them.
    for (int i = 0; i < values.length; i++) {
      final p = pointAt(i);
      final reveal = (i / math.max(1, values.length - 1));
      if (progress >= reveal) {
        canvas.drawCircle(p, 4.5, Paint()..color = Colors.white);
        canvas.drawCircle(
          p,
          4.5,
          Paint()
            ..color = AppColors.teal
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      if (i < labels.length) {
        final tp = TextPainter(
          text: TextSpan(text: labels[i], style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(p.dx - tp.width / 2, size.height - _bottomPad + 6));
      }
    }

    // Tooltip for the tapped point.
    if (touchedIndex != null && touchedIndex! < values.length) {
      final p = pointAt(touchedIndex!);
      final text = valueFormatter(values[touchedIndex!]);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final boxW = tp.width + 16;
      final boxH = tp.height + 10;
      var left = p.dx - boxW / 2;
      left = left.clamp(0.0, size.width - boxW);
      final top = math.max(0.0, p.dy - boxH - 10);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, top, boxW, boxH), const Radius.circular(8)),
        Paint()..color = AppColors.textDark.withValues(alpha: 0.92),
      );
      tp.paint(canvas, Offset(left + 8, top + 5));

      canvas.drawLine(
        Offset(p.dx, _topPad),
        Offset(p.dx, size.height - _bottomPad),
        Paint()
          ..color = AppColors.teal.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.progress != progress || old.touchedIndex != touchedIndex || old.values != values;
}