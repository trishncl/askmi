import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/report_model.dart';

/// One Manager → Owner report submission. Collapsed shows type, sender,
/// branch, date, and a Reviewed/Pending badge; expanded reveals the full
/// notes and — for the Owner only — a "Mark Reviewed" action.
class SubmittedReportCard extends StatefulWidget {
  final ReportModel report;
  final int index;
  final bool canReview;
  final Future<void> Function()? onMarkReviewed;

  const SubmittedReportCard({
    super.key,
    required this.report,
    required this.index,
    this.canReview = false,
    this.onMarkReviewed,
  });

  @override
  State<SubmittedReportCard> createState() => _SubmittedReportCardState();
}

class _SubmittedReportCardState extends State<SubmittedReportCard> {
  bool _expanded = false;
  bool _marking = false;

  Color get _typeColor {
    switch (widget.report.type) {
      case 'Financial Report':
        return AppColors.teal;
      case 'Inventory Report':
        return AppColors.gold;
      case 'Analytics Report':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData get _typeIcon {
    switch (widget.report.type) {
      case 'Financial Report':
        return Icons.payments_rounded;
      case 'Inventory Report':
        return Icons.inventory_2_rounded;
      case 'Analytics Report':
      default:
        return Icons.insights_rounded;
    }
  }

  Future<void> _markReviewed() async {
    if (widget.onMarkReviewed == null || _marking) return;
    setState(() => _marking = true);
    try {
      await widget.onMarkReviewed!();
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final color = _typeColor;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (widget.index.clamp(0, 8)) * 45),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14, offset: const Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(_typeIcon, size: 19, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.type, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.textDark)),
                            const SizedBox(height: 3),
                            Text(
                              '${r.branch} • ${r.senderName} • ${Fmt.dateTime.format(r.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textGray),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: r.reviewed ? AppColors.lightSuccess : AppColors.lightWarning,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          r.reviewed ? 'Reviewed' : 'Pending',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: r.reviewed ? AppColors.teal : AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                        Text(
                          r.notes.isEmpty ? 'No notes were added.' : r.notes,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: r.notes.isEmpty ? AppColors.textGray : AppColors.textDark,
                            fontStyle: r.notes.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        if (widget.canReview && !r.reviewed) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _marking ? null : _markReviewed,
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal, foregroundColor: Colors.white),
                              icon: _marking
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_rounded, size: 16),
                              label: Text(_marking ? 'Marking…' : 'Mark Reviewed'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeOutCubic,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}