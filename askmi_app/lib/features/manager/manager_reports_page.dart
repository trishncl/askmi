import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_box.dart';
import '../../models/report_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/reports_repository.dart';
import '../reports/widgets/submitted_report_card.dart';

/// PHASE 5 — Manager & Cashier. Manager GENERATES and submits a report to
/// the Owner — sender name and branch are auto-filled from the signed-in
/// Manager's own profile, never editable, so a submission can't be
/// misattributed. (There is no Owner-side inbox for these anymore — the
/// Owner's Reports screen dropped that entry point; submissions still
/// write to the same `reports` collection if that view comes back later.)
///
/// Standalone Scaffold (own AppBar) since ManagerShell doesn't exist yet —
/// drop this into that shell's body once it's built, same as every Owner
/// page already does inside OwnerShell.
class ManagerReportsPage extends StatefulWidget {
  const ManagerReportsPage({super.key});

  @override
  State<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage> {
  final _repo = ReportsRepository();
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  static const _types = ['Financial Report', 'Analytics Report', 'Inventory Report'];
  String _type = _types.first;
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String senderUid, String senderName, String branch) async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _repo.add(
        ReportModel(
          id: '',
          type: _type,
          branch: branch,
          senderUid: senderUid,
          senderName: senderName,
          notes: _notesCtrl.text.trim(),
          reviewed: false,
          createdAt: DateTime.now(),
        ),
      );
      _notesCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted to the Owner.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final senderUid = profile?.uid ?? '';
    final senderName = profile?.name ?? '';
    final branch = profile?.branch ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Submit Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Report', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  Text(
                    'Submitting as $senderName • $branch',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: InputDecoration(
                      labelText: 'Report Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'What should the Owner know?',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Notes are required' : null,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (senderUid.isEmpty || _submitting) ? null : () => _submit(senderUid, senderName, branch),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_submitting ? 'Submitting…' : 'Submit to Owner'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Your Submitted Reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
          const SizedBox(height: 12),
          if (senderUid.isEmpty)
            const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Profile not loaded',
              message: 'Sign in again to see your submission history.',
            )
          else
            StreamBuilder<List<ReportModel>>(
              stream: _repo.watchBySender(senderUid),
              builder: (context, snap) {
                final loading = snap.connectionState == ConnectionState.waiting;
                final error = snap.error;
                final mine = snap.data ?? const <ReportModel>[];

                if (error != null) {
                  return ErrorStateCard(message: 'Check your connection and try again.', onRetry: () => setState(() {}));
                }
                if (loading) {
                  return const ShimmerBox(height: 96, borderRadius: 18);
                }
                if (mine.isEmpty) {
                  return const EmptyState(
                    icon: Icons.outbox_outlined,
                    title: 'No reports submitted yet',
                    message: 'Reports you send to the Owner will show up here, along with their review status.',
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < mine.length; i++)
                      SubmittedReportCard(report: mine[i], index: i, canReview: false),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}