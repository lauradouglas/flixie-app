import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/country.dart';
import '../../providers/auth_provider.dart';
import '../../services/reference_data_service.dart';
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

  List<Country> _countries = [];
  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await ReferenceDataService.getCountries();
      if (mounted) {
        setState(() => _countries = countries);
      }
    } catch (_) {
      // Country list is optional; silently ignore load failures
    }
  }

  Future<void> _pickCountry() async {
    final country = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        countries: _countries,
        selected: _selectedCountry,
      ),
    );
    if (!mounted || country == null) return;
    setState(() => _selectedCountry = country);
  }

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
      countryId: _selectedCountry?.id,
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
            _CountryPickerField(
              selected: _selectedCountry,
              onTap: _countries.isEmpty ? null : _pickCountry,
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

// ---------------------------------------------------------------------------
// Country picker field (tappable, mimics AppTextField style)
// ---------------------------------------------------------------------------

class _CountryPickerField extends StatelessWidget {
  const _CountryPickerField({required this.selected, required this.onTap});

  final Country? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = selected != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.9),
          border: Border.all(
            color: FlixieColors.tabBarBorder.withValues(alpha: 0.9),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 22,
              color: FlixieColors.medium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasValue ? selected!.name : 'Country (optional)',
                style: TextStyle(
                  color: hasValue
                      ? FlixieColors.textPrimary
                      : FlixieColors.light.withValues(alpha: 0.86),
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: FlixieColors.medium,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country picker bottom sheet
// ---------------------------------------------------------------------------

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.countries, this.selected});

  final List<Country> countries;
  final Country? selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchController = TextEditingController();
  late List<Country> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.countries
          : widget.countries
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: FlixieColors.tabBarBorder.withValues(alpha: 0.85),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Country',
              style: TextStyle(
                color: FlixieColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: true,
              style: const TextStyle(color: FlixieColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                hintStyle: const TextStyle(color: FlixieColors.medium),
                prefixIcon:
                    const Icon(Icons.search, color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FlixieColors.tabBarBorder.withValues(alpha: 0.85),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: FlixieColors.tabBarBorder.withValues(alpha: 0.85),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: FlixieColors.primary,
                    width: 1.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final country = _filtered[index];
                  final isSelected = country.id == widget.selected?.id;
                  return ListTile(
                    tileColor: Colors.transparent,
                    title: Text(
                      country.name,
                      style: TextStyle(
                        color: isSelected
                            ? FlixieColors.primary
                            : FlixieColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: FlixieColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
