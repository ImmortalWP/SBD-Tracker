import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

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
    if (_isRegister && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
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
      backgroundColor: AppTheme.bg950,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.fitness_center, color: AppTheme.accentRed, size: 34),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SBD Tracker',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.text50,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isRegister ? 'Create your account' : 'Welcome back, lifter',
                  style: const TextStyle(color: AppTheme.text500, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // Error
                if (_error.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13))),
                      ],
                    ),
                  ),

                // Username
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'USERNAME',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),

                // Password
                TextField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'PASSWORD',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),

                if (_isRegister) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CONFIRM PASSWORD',
                      prefixIcon: Icon(Icons.lock_outline, size: 20),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_isRegister ? 'CREATE ACCOUNT' : 'SIGN IN'),
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle
                TextButton(
                  onPressed: () => setState(() { _isRegister = !_isRegister; _error = ''; }),
                  child: Text(
                    _isRegister ? 'Already have an account? Sign in' : 'Don\'t have an account? Register',
                    style: TextStyle(color: AppTheme.text400, fontSize: 13),
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
