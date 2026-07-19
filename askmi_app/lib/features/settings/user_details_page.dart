import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/role_permissions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_activity_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_providers.dart';
import '../../repositories/users_repository.dart';
import '../../services/user_admin_service.dart';
import 'user_activity_log_page.dart';
import 'user_form_page.dart';

class UserDetailsPage extends StatefulWidget {
  final UserModel user;
  const UserDetailsPage({super.key, required this.user});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  final _usersRepo = UsersRepository();
  final _adminService = UserAdminService();
  late UserModel _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  bool get _isSelf => context.read<UserProfileProvider>().profile?.uid == _user.uid;

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UserFormPage(existing: _user)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _refresh() async {
    final fresh = await _usersRepo.fetchByUid(_user.uid);
    if (fresh != null && mounted) setState(() => _user = fresh);
  }

  Future<void> _toggleStatus() async {
    if (_isSelf && _user.displayRole == 'Owner') {
      _snack("Owners can't deactivate their own account.");
      return;
    }
    final activating = !_user.active;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activating ? 'Activate account?' : 'Deactivate account?'),
        content: Text(
          activating
              ? '${_user.displayName} will be able to sign in again.'
              : '${_user.displayName} will be signed out and unable to sign in until reactivated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activating ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _adminService.setStatus(_user, activating ? 'active' : 'inactive');
      await _refresh();
      _snack(activating ? 'Account activated.' : 'Account deactivated.');
    } on UserAdminException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send password reset?'),
        content: Text("A reset link will be emailed to ${_user.email}."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _adminService.sendPasswordReset(_user);
      _snack('Password reset email sent.');
    } on UserAdminException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _user.permissions.isEmpty
        ? defaultPermissionsForRole(_user.displayRole)
        : _user.permissions;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('User Details'),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _busy ? null : _edit),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _profileHeader(),
            const SizedBox(height: 16),
            _sectionCard(
              title: 'Contact Details',
              children: [
                _row(Icons.mail_outline_rounded, 'Email', _user.email),
                _row(Icons.alternate_email_rounded, 'Username', _user.username),
                _row(Icons.phone_outlined, 'Contact Number',
                    _user.contactNumber.isEmpty ? '—' : _user.contactNumber),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Role & Assignment',
              children: [
                _row(Icons.shield_outlined, 'Role', _user.displayRole),
                _row(Icons.storefront_outlined, 'Branch', _user.branch),
                _row(Icons.toggle_on_outlined, 'Status', _user.status[0].toUpperCase() + _user.status.substring(1)),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Account Timeline',
              children: [
                _row(Icons.calendar_today_outlined, 'Created', Fmt.dateTime.format(_user.createdAt)),
                _row(Icons.update_rounded, 'Last Updated', Fmt.dateTime.format(_user.updatedAt)),
                _row(
                  Icons.login_rounded,
                  'Last Login',
                  _user.lastLoginAt == null ? 'Never signed in' : Fmt.dateTime.format(_user.lastLoginAt!),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionCard(
              title: 'Operational Activity',
              children: [
                _row(Icons.receipt_long_outlined, 'Sales Transactions', '${_user.salesTransactionsCreated}'),
                _row(Icons.inventory_2_outlined, 'Inventory Logs Submitted', '${_user.inventoryLogsSubmitted}'),
              ],
            ),
            const SizedBox(height: 14),
            _permissionsCard(permissions),
            const SizedBox(height: 14),
            _actionsRow(),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserActivityLogPage(user: _user)),
              ),
              icon: const Icon(Icons.history_rounded),
              label: const Text('View Full Activity Log'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, Color(0xFF1F8377)],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: _user.profileImageUrl.isNotEmpty ? NetworkImage(_user.profileImageUrl) : null,
            child: _user.profileImageUrl.isEmpty
                ? Text(
                    _user.initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user.displayName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_user.displayRole} · ${_user.branch}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textDark)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textGray),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textGray)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permissionsCard(Map<String, bool> permissions) {
    return _sectionCard(
      title: 'Module Permissions',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in kPermissionLabels.entries)
              _permissionChip(entry.value, permissions[entry.key] ?? false),
          ],
        ),
      ],
    );
  }

  Widget _permissionChip(String label, bool granted) {
    final color = granted ? AppColors.active : AppColors.inactive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(granted ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _actionsRow() {
    final canToggle = !(_isSelf && _user.displayRole == 'Owner');
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _resetPassword,
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text('Reset Password'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy || !canToggle ? null : _toggleStatus,
            style: OutlinedButton.styleFrom(
              foregroundColor: _user.active ? AppColors.danger : AppColors.active,
              side: BorderSide(color: (_user.active ? AppColors.danger : AppColors.active).withValues(alpha: 0.4)),
            ),
            icon: const Icon(Icons.power_settings_new_rounded),
            label: Text(_user.active ? 'Deactivate' : 'Activate'),
          ),
        ),
      ],
    );
  }
}