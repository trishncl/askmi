import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/report_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/reports_repository.dart';
import 'widgets/submitted_report_card.dart';

enum _StatusFilter { all, pending, reviewed }

/// Owner's inbox for reports a Manager submitted (Financial / Analytics /
/// Inventory report notes) — separate from ReportsPage, which is the
/// Sales/Inventory/Products/Branch Performance analytics screen. This one
/// reads the `reports` Firestore collection (ReportModel); that one reads
/// the operational collections directly. Different data, different screen.
class SubmittedReportsPage extends StatefulWidget {
  const SubmittedReportsPage({super.key});

  @override
  State<SubmittedReportsPage> createState() => _SubmittedReportsPageState();
}

class _SubmittedReportsPageState extends State<SubmittedReportsPage> {
  final _repo = ReportsRepository();
  _StatusFilter _status = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final branch = context.watch<BranchScope>().filterOrNull;
    final role = (context.watch<UserProfileProvider>().profile?.role ?? '').toLowerCase();
    final canReview = role == 'owner';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Submitted Reports')),
      body: StreamBuilder<List<ReportModel>>(
        stream: _repo.watchAll(branch: branch, orderByField: 'createdAt'),
        builder: (context, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final error = snap.error;
          final all = snap.data ?? const <ReportModel>[];

          final filtered = switch (_status) {
            _StatusFilter.all => all,
            _StatusFilter.pending => all.where((r) => !r.reviewed).toList(),
            _StatusFilter.reviewed => all.where((r) => r.reviewed).toList(),
          };
          final pendingCount = all.where((r) => !r.reviewed).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                '${all.length} submission${all.length == 1 ? '' : 's'} • $pendingCount pending review',
                style: const TextStyle(color: AppColors.textGray, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statusChip('All', _StatusFilter.all),
                  const SizedBox(width: 8),
                  _statusChip('Pending', _StatusFilter.pending),
                  const SizedBox(width: 8),
                  _statusChip('Reviewed', _StatusFilter.reviewed),
                ],
              ),
              const SizedBox(height: 16),
              if (error != null)
                ErrorStateCard(message: _friendlyError(error), onRetry: () => setState(() {}))
              else if (loading) ...[
                const ShimmerBox(height: 96, borderRadius: 18),
                const SizedBox(height: 12),
                const ShimmerBox(height: 96, borderRadius: 18),
              ] else if (filtered.isEmpty)
                EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: _status == _StatusFilter.pending ? 'Nothing pending' : 'No submissions found',
                  message: _status == _StatusFilter.pending
                      ? 'Every report a Manager has sent has been reviewed.'
                      : 'Manager-submitted reports will show up here.',
                )
              else
                for (int i = 0; i < filtered.length; i++)
                  SubmittedReportCard(
                    report: filtered[i],
                    index: i,
                    canReview: canReview,
                    onMarkReviewed: canReview ? () => _repo.markReviewed(filtered[i].id) : null,
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusChip(String label, _StatusFilter value) {
    final selected = _status == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _status = value),
      selectedColor: AppColors.lightSuccess,
      labelStyle: TextStyle(
        color: selected ? AppColors.teal : AppColors.textGray,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  String _friendlyError(Object error) {
    final s = error.toString();
    if (s.contains('permission-denied')) return "You don't have access to this data. Check your Firestore rules.";
    if (s.contains('failed-precondition') || s.contains('index')) {
      return 'This query needs a Firestore index. Open the debug console — Firebase logs a direct link to create it.';
    }
    return 'Check your connection and try again.';
  }
}