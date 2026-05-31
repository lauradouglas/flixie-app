import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../../widgets/flixie_wordmark.dart';
import 'auth_ui.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const _usernameDebounceDuration = Duration(milliseconds: 350);

  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      if (mounted) {
        setState(() {
          _checkingUsername = false;
          _usernameAvailable = null;
        });
      }
      return;
    }

    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });

    try {
      final exists = await UserService.usernameExists(username);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = !exists;
      });
    } catch (error) {
      logger.e('Username check failed: $error');
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
      });
    }
  }

  void _onUsernameChanged(String _) {
    _usernameDebounce?.cancel();
    setState(() => _usernameAvailable = null);
    _usernameDebounce = Timer(_usernameDebounceDuration, () {
      _checkUsernameAvailability();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_usernameAvailable != true) {
      await _checkUsernameAvailability();
      if (!mounted) return;
      if (_usernameAvailable != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please choose an available username.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
        return;
      }
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      username: _usernameController.text.trim(),
    );

    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.errorMessage ?? 'Sign up failed.'),
        backgroundColor: FlixieColors.danger,
      ),
    );
  }

  Widget? _buildUsernameSuffix() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_usernameAvailable == true) {
      return const Icon(Icons.check_circle, color: FlixieColors.success);
    }
    if (_usernameAvailable == false) {
      return const Icon(Icons.cancel, color: FlixieColors.danger);
    }
    return null;
  }

  Widget? _buildEmailSuffix() {
    final value = _emailController.text.trim();
    if (value.isEmpty) return null;
    return Icon(
      isValidEmailFormat(value) ? Icons.check_circle : Icons.error_outline,
      color:
          isValidEmailFormat(value) ? FlixieColors.success : FlixieColors.danger,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLoading = context.select<AuthProvider, bool>((p) => p.isLoading);

    return AuthScaffold(
      topLabel: 'Step 1 of 3',
      title: Text.rich(
        TextSpan(
          style: textTheme.displaySmall?.copyWith(
            color: FlixieColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
          children: [
            const TextSpan(text: 'Join '),
            flixieWordmarkSpan(
              fontSize: textTheme.displaySmall?.fontSize ?? 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      subtitle: 'Secure your account with the basics.',
      onBack: () => context.pop(),
      cardPadding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OnboardingProgressIndicator(currentStep: 0, totalSteps: 3),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                    prefixIcon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.givenName],
                    validator: _requiredNameValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                    prefixIcon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.familyName],
                    validator: _requiredNameValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _usernameController,
              label: 'Username',
              prefixIcon: Icons.alternate_email_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: _onUsernameChanged,
              suffixIcon: _buildUsernameSuffix(),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Please enter a username.';
                if (raw.length < 3) {
                  return 'Username must be at least 3 characters.';
                }
                if (_usernameAvailable == false) {
                  return 'This username is already taken.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _emailController,
              label: 'Email Address',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onChanged: (_) => setState(() {}),
              suffixIcon: _buildEmailSuffix(),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) return 'Please enter your email.';
                if (!isValidEmailFormat(raw)) return 'Please enter a valid email.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password.';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            PasswordStrengthBar(password: _passwordController.text),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password.';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Continue',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: textTheme.bodyMedium?.copyWith(color: FlixieColors.light),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: FlixieColors.primaryTint,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Sign In',
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

  String? _requiredNameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}
