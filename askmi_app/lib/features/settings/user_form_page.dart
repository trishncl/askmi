import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/branch_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_button.dart';
import '../../models/user_model.dart';
import '../../repositories/users_repository.dart';
import '../../services/user_admin_service.dart';
import '../../core/utils/dropdown_utils.dart';
import '../../core/widgets/safe_dropdown_form_field.dart';

const _kRoles = ['Owner', 'Manager', 'Cashier'];
const _kStatuses = ['active', 'inactive', 'pending'];
final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');

/// Add / edit a user profile. Doubles as both by taking an optional
/// [existing], same shape as SaleFormPage.
///
/// Account CREATION and field UPDATES both go through UserAdminService,
/// which calls Cloud Functions — this page never touches Firebase Auth or
/// writes the `users` doc directly. That's the boundary the security brief
/// requires: no Admin-SDK-shaped privileged operation may run on-device.
class UserFormPage extends StatefulWidget {
  final UserModel? existing;
  const UserFormPage({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _usersRepo = UsersRepository();
  final _adminService = UserAdminService();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _imageUrlCtrl;

  late String _role;
  late String _branch;
  late String _status;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _firstNameCtrl = TextEditingController(text: e?.firstName ?? '')..addListener(_markDirty);
    _lastNameCtrl = TextEditingController(text: e?.lastName ?? '')..addListener(_markDirty);
    _usernameCtrl = TextEditingController(text: e?.username ?? '')..addListener(_markDirty);
    _emailCtrl = TextEditingController(text: e?.email ?? '')..addListener(_markDirty);
    _contactCtrl = TextEditingController(text: e?.contactNumber ?? '')..addListener(_markDirty);
    _passwordCtrl = TextEditingController()..addListener(_markDirty);
    _imageUrlCtrl = TextEditingController(text: e?.profileImageUrl ?? '')..addListener(_markDirty);
    _role = resolveDropdownValue(
      value: e?.displayRole,
      items: _kRoles,
      fallback: 'Cashier',
    );
    _branch = resolveDropdownValue(
      value: e?.branch,
      items: kBranchNames,
      fallback: kBranchNames.first,
    );
    _status = resolveDropdownValue(
      value: e?.status,
      items: _kStatuses,
      fallback: 'active',
    );
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _passwordCtrl.dispose();
    _imageUrlCtrl.dispose();
    super.dispose();
  }

  bool get _branchRequired => _role == 'Manager' || _role == 'Cashier';

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Leaving now will lose them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep Editing')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final username = _usernameCtrl.text.trim();
      final email = _emailCtrl.text.trim().toLowerCase();

      final usernameTaken = await _usersRepo.isUsernameTaken(username, excludeUid: widget.existing?.uid);
      if (usernameTaken) {
        _fail('That username is already taken.');
        return;
      }
      final emailTaken = await _usersRepo.isEmailTaken(email, excludeUid: widget.existing?.uid);
      if (emailTaken) {
        _fail('That email address is already registered.');
        return;
      }

      if (widget.isEditing) {
        await _adminService.updateUser(
          existing: widget.existing!,
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          username: username,
          contactNumber: _contactCtrl.text,
          role: _role,
          branch: _branchRequired ? _branch : 'All Branches',
          status: _status,
          profileImageUrl: _imageUrlCtrl.text,
        );
      } else {
        await _adminService.createUser(
          firstName: _firstNameCtrl.text,
          lastName: _lastNameCtrl.text,
          username: username,
          email: email,
          contactNumber: _contactCtrl.text,
          role: _role,
          branch: _branchRequired ? _branch : 'All Branches',
          password: _passwordCtrl.text,
          status: _status,
          profileImageUrl: _imageUrlCtrl.text,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on UserAdminException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: Text(widget.isEditing ? 'Edit User' : 'Add User')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _firstNameCtrl,
                      label: 'First Name',
                      icon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required.' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _lastNameCtrl,
                      label: 'Last Name',
                      icon: Icons.badge_outlined,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required.' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(
                controller: _usernameCtrl,
                label: 'Username',
                icon: Icons.alternate_email_rounded,
                inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Username is required.';
                  if (t.length < 3) return 'Too short — at least 3 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                // Email is the Auth identity — never editable after the
                // account exists, only settable at creation.
                enabled: !widget.isEditing,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Email is required.';
                  if (!_emailRegex.hasMatch(t)) return 'Enter a valid email address.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _field(
                controller: _contactCtrl,
                label: 'Contact Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required.' : null,
              ),
              const SizedBox(height: 14),
              SafeDropdownFormField(
                label: 'Role',
                icon: Icons.shield_outlined,
                value: _role,
                items: _kRoles,
                fallback: 'Cashier',
                onChanged: (v) => setState(() {
                  _role = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 14),
              if (_branchRequired) ...[
                SafeDropdownFormField(
                  label: 'Assigned Branch',
                  icon: Icons.storefront_rounded,
                  value: _branch,
                  items: kBranchNames,
                  fallback: kBranchNames.first,
                  onChanged: (v) => setState(() {
                    _branch = v;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: 14),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Owners have access to all branches — no branch assignment needed.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textGray),
                  ),
                ),
              if (!widget.isEditing) ...[
                _field(
                  controller: _passwordCtrl,
                  label: 'Temporary Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) {
                    final t = v ?? '';
                    if (t.length < 8) return 'At least 8 characters.';
                    if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'[0-9]').hasMatch(t)) {
                      return 'Include at least one letter and one number.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'The user will be asked to change this after their first sign-in.',
                  style: TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
                const SizedBox(height: 14),
              ],
              SafeDropdownFormField(
                label: 'Status',
                icon: Icons.toggle_on_outlined,
                value: _status,
                items: _kStatuses,
                fallback: 'active',
                onChanged: (v) => setState(() {
                  _status = v;
                  _dirty = true;
                }),
              ),
              const SizedBox(height: 14),
              _field(
                controller: _imageUrlCtrl,
                label: 'Profile Image URL (optional)',
                icon: Icons.image_outlined,
              ),
              const SizedBox(height: 24),
              GradientButton(
                label: widget.isEditing ? 'Save Changes' : 'Create User',
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enabled: enabled,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ignore: unused_element
  Widget _dropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: [
        for (final i in items) DropdownMenuItem(value: i, child: Text(i)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}