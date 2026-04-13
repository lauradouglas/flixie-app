import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/country.dart';
import '../../models/genre.dart';
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

  // Dropdown touched tracking
  bool _languageTouched = false;
  bool _countryTouched = false;
  bool _submitAttempted = false;

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

  // Genre multi-select
  List<Genre> _genres = [];
  final Set<int> _selectedGenreIds = {};

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
        ReferenceDataService.getGenres(),
      ]);
      if (mounted) {
        setState(() {
          _languages = results[0] as List<Language>;
          _countries = results[1] as List<Country>;
          _genres = results[2] as List<Genre>;
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
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;

    // Capture messenger before any await so it's safe after navigation
    final messenger = ScaffoldMessenger.of(context);

    // Ensure username availability has been confirmed.
    if (_usernameAvailable != true) {
      await _checkUsernameAvailability();
      if (!mounted) return;
      if (_usernameAvailable != true) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please choose an available username.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
        return;
      }
    }

    if (_selectedLanguage == null || _selectedCountry == null) {
      messenger.showSnackBar(
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
      genreIds: _selectedGenreIds.toList(),
    );

    if (!mounted) return;
    if (!success) {
      messenger.showSnackBar(
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

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    final inputEnabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
    );
    final inputFocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: FlixieColors.primary, width: 1.5),
    );
    final inputFill = Colors.white.withOpacity(0.06);
    const inputStyle = TextStyle(color: Colors.white);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D1B2A),
                  Color(0xFF172B4D),
                  Color(0xFF1A1040),
                ],
              ),
            ),
          ),
          // Subtle purple glow top-right
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlixieColors.primary.withOpacity(0.10),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // AppBar-style header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: FlixieColors.light),
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Create Account',
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Text(
                            'Join Flixie',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create your account to get started',
                            style: textTheme.bodyMedium?.copyWith(
                              color: FlixieColors.light.withOpacity(0.65),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // First & Last name row
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _firstNameController,
                                        keyboardType: TextInputType.name,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        style: inputStyle,
                                        decoration: InputDecoration(
                                          labelText: 'First Name',
                                          filled: true,
                                          fillColor: inputFill,
                                          border: inputBorder,
                                          enabledBorder: inputEnabledBorder,
                                          focusedBorder: inputFocusedBorder,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lastNameController,
                                        keyboardType: TextInputType.name,
                                        textCapitalization:
                                            TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        style: inputStyle,
                                        decoration: InputDecoration(
                                          labelText: 'Last Name',
                                          filled: true,
                                          fillColor: inputFill,
                                          border: inputBorder,
                                          enabledBorder: inputEnabledBorder,
                                          focusedBorder: inputFocusedBorder,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Username
                                Focus(
                                  onFocusChange: (hasFocus) {
                                    if (!hasFocus) _checkUsernameAvailability();
                                  },
                                  child: TextFormField(
                                    controller: _usernameController,
                                    textInputAction: TextInputAction.next,
                                    style: inputStyle,
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      prefixIcon: const Icon(
                                          Icons.alternate_email,
                                          size: 20),
                                      suffixIcon: _buildUsernameSuffix(),
                                      filled: true,
                                      fillColor: inputFill,
                                      border: inputBorder,
                                      enabledBorder: inputEnabledBorder,
                                      focusedBorder: inputFocusedBorder,
                                    ),
                                    onChanged: (_) {
                                      if (_usernameAvailable != null) {
                                        setState(
                                            () => _usernameAvailable = null);
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
                                const SizedBox(height: 14),

                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: inputStyle,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        size: 20),
                                    filled: true,
                                    fillColor: inputFill,
                                    border: inputBorder,
                                    enabledBorder: inputEnabledBorder,
                                    focusedBorder: inputFocusedBorder,
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
                                const SizedBox(height: 14),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  style: inputStyle,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outlined,
                                        size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                    filled: true,
                                    fillColor: inputFill,
                                    border: inputBorder,
                                    enabledBorder: inputEnabledBorder,
                                    focusedBorder: inputFocusedBorder,
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
                                const SizedBox(height: 14),

                                // Confirm password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.next,
                                  style: inputStyle,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    prefixIcon: const Icon(Icons.lock_outlined,
                                        size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    ),
                                    filled: true,
                                    fillColor: inputFill,
                                    border: inputBorder,
                                    enabledBorder: inputEnabledBorder,
                                    focusedBorder: inputFocusedBorder,
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
                                const SizedBox(height: 20),

                                // Language / Country / Genres
                                if (_loadingRefData)
                                  const Center(
                                      child: CircularProgressIndicator())
                                else if (_refDataError)
                                  _buildRefDataErrorRow(
                                      onRetry: _loadReferenceData)
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownFlutter<Language>(
                                        items: _languages,
                                        initialItem: _selectedLanguage,
                                        hintText: 'Select Language',
                                        onChanged: (l) => setState(() {
                                          _selectedLanguage = l;
                                          _languageTouched = true;
                                        }),
                                        headerBuilder: (ctx, item, _) =>
                                            Text(item.name),
                                        listItemBuilder:
                                            (ctx, item, isSelected, _) =>
                                                Text(item.name),
                                        decoration: CustomDropdownDecoration(
                                          closedFillColor: Theme.of(context)
                                              .inputDecorationTheme
                                              .fillColor,
                                          expandedFillColor: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          closedBorder: Border.all(
                                            color: FlixieColors.primary
                                                .withValues(alpha: 0.4),
                                          ),
                                          expandedBorder: Border.all(
                                              color: FlixieColors.primary),
                                        ),
                                      ),
                                      if (_selectedLanguage == null &&
                                          (_languageTouched || _submitAttempted))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 6, left: 12),
                                          child: Text(
                                            'Please select a language.',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 14),
                                      DropdownFlutter<Country>.search(
                                        items: _countries,
                                        initialItem: _selectedCountry,
                                        hintText: 'Select Country',
                                        onChanged: (c) => setState(() {
                                          _selectedCountry = c;
                                          _countryTouched = true;
                                        }),
                                        headerBuilder: (ctx, item, _) =>
                                            Text(item.name),
                                        listItemBuilder:
                                            (ctx, item, isSelected, _) =>
                                                Text(item.name),
                                        decoration: CustomDropdownDecoration(
                                          closedFillColor: Theme.of(context)
                                              .inputDecorationTheme
                                              .fillColor,
                                          expandedFillColor: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          closedBorder: Border.all(
                                            color: FlixieColors.primary
                                                .withValues(alpha: 0.4),
                                          ),
                                          expandedBorder: Border.all(
                                              color: FlixieColors.primary),
                                          searchFieldDecoration:
                                              SearchFieldDecoration(
                                            fillColor: Theme.of(context)
                                                .inputDecorationTheme
                                                .fillColor,
                                          ),
                                        ),
                                      ),
                                      if (_selectedCountry == null &&
                                          (_countryTouched || _submitAttempted))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 6, left: 12),
                                          child: Text(
                                            'Please select a country.',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      if (_genres.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        ..._buildGenrePicker(textTheme),
                                      ],
                                    ],
                                  ),

                                const SizedBox(height: 20),

                                // Create account button
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        FlixieColors.primary,
                                        Color(0xFF6B5BD6),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: FlixieColors.primary
                                            .withOpacity(0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      minimumSize:
                                          const Size.fromHeight(50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Create Account',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Sign in link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already have an account?',
                                style: textTheme.bodySmall?.copyWith(
                                  color: FlixieColors.light.withOpacity(0.6),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: FlixieColors.primary,
                                ),
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefDataErrorRow({required VoidCallback onRetry}) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: FlixieColors.danger, size: 20),
        const SizedBox(width: 8),
        const Expanded(
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

  List<Widget> _buildGenrePicker(TextTheme textTheme) {
    return [
      Row(
        children: [
          Text('Favourite Genres', style: textTheme.titleSmall),
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _genres.map((genre) {
          final selected = _selectedGenreIds.contains(genre.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _selectedGenreIds.remove(genre.id);
              } else {
                _selectedGenreIds.add(genre.id);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? FlixieColors.primary.withValues(alpha: 0.2)
                    : FlixieColors.tabBarBackgroundFocused,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? FlixieColors.primary
                      : FlixieColors.tabBarBorder,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check_rounded,
                        size: 14, color: FlixieColors.primary),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    genre.name,
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          selected ? FlixieColors.primary : FlixieColors.light,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ];
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
