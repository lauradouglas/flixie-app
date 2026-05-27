import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/flixie_wordmark.dart';
import 'auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthProvider>();

    final success = await auth.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (!_rememberMe) {
      _emailController.clear();
      _passwordController.clear();
    }

    if (!mounted) return;
    if (!success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Sign in failed.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLoading = context.select<AuthProvider, bool>((p) => p.isLoading);

    return AuthScaffold(
      topLabel: 'Welcome Back',
      title: const FlixieWordmark(
        fontSize: 46,
        textAlign: TextAlign.center,
      ),
      subtitle: 'Sign in to continue to your account',
      onBack: () => Navigator.of(context).maybePop(),
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailController,
              label: 'Email or Username',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email or username.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              textInputAction: TextInputAction.done,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: FlixieColors.light,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    value: _rememberMe,
                    onChanged: (value) => setState(
                      () => _rememberMe = value ?? false,
                    ),
                    title: Text(
                      'Remember me',
                      style: textTheme.bodyMedium?.copyWith(
                        color: FlixieColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: FlixieColors.primary,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/auth/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: FlixieColors.primaryTint,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Sign In',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(
                  TextSpan(
                    style: textTheme.bodyMedium?.copyWith(
                      color: FlixieColors.light,
                    ),
                    children: [
                      const TextSpan(text: 'New to '),
                      flixieWordmarkSpan(
                        fontSize: (textTheme.bodyMedium?.fontSize ?? 14),
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => context.push('/auth/signup'),
                  style: TextButton.styleFrom(
                    foregroundColor: FlixieColors.primaryTint,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
