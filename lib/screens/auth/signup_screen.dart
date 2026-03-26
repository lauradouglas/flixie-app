import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/country.dart';
import '../../models/language.dart';
import '../../providers/auth_provider.dart';
import '../../services/reference_data_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Username availability
  bool _checkingUsername = false;
  bool? _usernameAvailable; // null = not checked yet

  // Reference data
  List<Language> _languages = [];
  List<Country> _countries = [];
  bool _loadingRefData = true;
  bool _refDataError = false;

  Language? _selectedLanguage;
  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    if (mounted && _refDataError) {
      // Reset error state before retrying.
      setState(() {
        _loadingRefData = true;
        _refDataError = false;
      });
    }
    try {
      final results = await Future.wait([
        ReferenceDataService.getLanguages(),
        ReferenceDataService.getCountries(),
      ]);
      if (mounted) {
        setState(() {
          _languages = results[0] as List<Language>;
          _countries = results[1] as List<Country>;
          _loadingRefData = false;
        });
      }
    } catch (e) {
      logger.e('Failed to load reference data: $e');
      if (mounted) {
        setState(() {
          _loadingRefData = false;
          _refDataError = true;
        });
      }
    }
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });

    try {
      final exists = await UserService.usernameExists(username);
      if (mounted) {
        setState(() {
          _usernameAvailable = !exists;
          _checkingUsername = false;
        });
      }
    } catch (e) {
      logger.e('Username check failed: $e');
      if (mounted) {
        setState(() {
          _usernameAvailable = null;
          _checkingUsername = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    // Re-validate form (also triggers username field validator).
    if (!_formKey.currentState!.validate()) return;

    // Ensure username availability has been confirmed.
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

    if (_selectedLanguage == null || _selectedCountry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a language and country.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: _emailController.text,
      password: _passwordController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      username: _usernameController.text,
      languageId: _selectedLanguage!.id,
      countryId: _selectedCountry!.id,
    );

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Sign up failed.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isLoading = context.select<AuthProvider, bool>((p) => p.isLoading);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join Flixie',
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your account to get started',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // First name
                TextFormField(
                  controller: _firstNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your first name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Last name
                TextFormField(
                  controller: _lastNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your last name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username
                Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _checkUsernameAvailability();
                  },
                  child: TextFormField(
                    controller: _usernameController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.alternate_email),
                      suffixIcon: _buildUsernameSuffix(),
                    ),
                    onChanged: (_) {
                      if (_usernameAvailable != null) {
                        setState(() => _usernameAvailable = null);
                      }
                    },
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter a username.';
                      }
                      if (v.trim().length < 3) {
                        return 'Username must be at least 3 characters.';
                      }
                      if (_usernameAvailable == false) {
                        return 'This username is already taken.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email.';
                    }
                    if (!v.contains('@')) {
                      return 'Please enter a valid email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Language dropdown
                if (_loadingRefData)
                  const Center(child: CircularProgressIndicator())
                else if (_refDataError)
                  _buildRefDataErrorRow(onRetry: _loadReferenceData)
                else
                  DropdownButtonFormField<Language>(
                        value: _selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          prefixIcon: Icon(Icons.language),
                        ),
                        items: _languages
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(l.name),
                              ),
                            )
                            .toList(),
                        onChanged: (l) =>
                            setState(() => _selectedLanguage = l),
                        validator: (v) => v == null
                            ? 'Please select a language.'
                            : null,
                      ),
                const SizedBox(height: 16),

                // Country dropdown
                if (_loadingRefData)
                  const Center(child: CircularProgressIndicator())
                else if (_refDataError)
                  const SizedBox.shrink()
                else
                  DropdownButtonFormField<Country>(
                        value: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: _countries
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (c) =>
                            setState(() => _selectedCountry = c),
                        validator: (v) => v == null
                            ? 'Please select a country.'
                            : null,
                      ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter a password.';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm your password.';
                    }
                    if (v != _passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Create account button
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),

                const SizedBox(height: 24),

                // Log in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: textTheme.bodySmall,
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefDataErrorRow({required VoidCallback onRetry}) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: FlixieColors.danger, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Failed to load options.',
            style: TextStyle(color: FlixieColors.danger),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget? _buildUsernameSuffix() {
    if (_checkingUsername) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
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
}

