import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  String _error = '';

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username and password are required.');
      return;
    }
    if (_isRegister && password != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_isRegister && password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _loading = true; _error = ''; });
    try {
      final auth = context.read<AuthService>();
      if (_isRegister) {
        await auth.register(username, password);
      } else {
        await auth.login(username, password);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Spacing.xxl),
                // Brand
                Text(
                  'SBD',
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: 48,
                    color: AppColors.accentBlue,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'TRACKER',
                  style: AppTypography.label.copyWith(
                    letterSpacing: 6,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: Spacing.xxl + Spacing.base),
                Text(
                  _isRegister ? 'Create your account' : 'Welcome back',
                  style: AppTypography.h2,
                ),
                const SizedBox(height: Spacing.xxl),

                // Error
                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: Spacing.base),
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.accentRed, size: 16),
                        const SizedBox(width: Spacing.sm),
                        Expanded(child: Text(_error, style: AppTypography.bodySmall.copyWith(color: AppColors.accentRed))),
                      ],
                    ),
                  ),

                // Username
                TextField(
                  controller: _usernameCtrl,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    labelText: 'USERNAME',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                ),
                const SizedBox(height: Spacing.md),

                // Password
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: AppTypography.body,
                  decoration: const InputDecoration(
                    labelText: 'PASSWORD',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),

                if (_isRegister) ...[
                  const SizedBox(height: Spacing.md),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    style: AppTypography.body,
                    decoration: const InputDecoration(
                      labelText: 'CONFIRM PASSWORD',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                ],
                const SizedBox(height: Spacing.xl),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isRegister ? 'Create Account' : 'Sign In'),
                  ),
                ),
                const SizedBox(height: Spacing.base),

                // Toggle
                GestureDetector(
                  onTap: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
                  child: Text(
                    _isRegister ? 'Already have an account? Sign in' : 'Don\'t have an account? Register',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}
