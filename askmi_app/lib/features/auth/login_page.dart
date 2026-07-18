import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/gradient_button.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _cardController;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
    );
    _cardController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // No navigation here on purpose: this screen is rendered BY AuthGate
      // when signed out. Once sign-in succeeds, AuthState notifies, AuthGate
      // rebuilds, and it swaps this screen out for whatever comes next —
      // no Navigator push/pop needed, so there's no race to get wrong.
    } on Exception catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Exception e) {
    final msg = e.toString();
    if (msg.contains('user-not-found') ||
        msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'Sign in failed. Please check your connection and try again.';
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type your email above first, then tap this again.')),
      );
      return;
    }
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't send reset email.")));
      }
    }
  }

  void _showCreateAccountInfo() {
    // Deliberately NOT a public signup form — see the earlier architecture
    // decision: every account (Owner/Manager/Cashier) is provisioned by
    // the Owner via Settings, once that's built in Phase 4.
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accounts are created by the owner'),
        content: const Text(
          "AA's Lomi doesn't use public sign-up. Ask your branch owner to "
          'add you as a user and they\'ll give you a login to use here.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background: soft gradient + a couple of very low-opacity
          // decorative shapes, per the brief.
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: _backgroundBlob(180, AppColors.orange.withValues(alpha: 0.06)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _backgroundBlob(220, AppColors.teal.withValues(alpha: 0.06)),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const AppLogo(size: 64),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome Back',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue discovering delicious meals.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 28),

                  AnimatedBuilder(
                    animation: _cardController,
                    builder: (context, child) => Opacity(
                      opacity: _cardFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _cardSlide.value),
                        child: child,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _forgotPassword,
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 4),
                            Text(_error!, style: const TextStyle(color: AppColors.danger)),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 8),
                          GradientButton(
                            label: 'Sign In',
                            loading: _loading,
                            onPressed: _loading ? null : _signIn,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?",
                          style: GoogleFonts.poppins(color: AppColors.textGray)),
                      TextButton(
                        onPressed: _showCreateAccountInfo,
                        child: const Text('Create Account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}