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
import 'auth_ui.dart';

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
  bool _languageTouched = false;
  bool _countryTouched = false;
  bool _submitAttempted = false;
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  bool _loadingRefData = true;
  bool _refDataError = false;

  List<Language> _languages = [];
  List<Country> _countries = [];
  List<Genre> _genres = [];

  Language? _selectedLanguage;
  Country? _selectedCountry;
  final Set<int> _selectedGenreIds = {};

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    if (mounted && _refDataError) {
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

      if (!mounted) return;
      setState(() {
        _languages = results[0] as List<Language>;
        _countries = results[1] as List<Country>;
        _genres = filterSupportedGenres(results[2] as List<Genre>);
        _loadingRefData = false;
      });
    } catch (error) {
      logger.e('Failed to load reference data: $error');
      if (!mounted) return;
      setState(() {
        _loadingRefData = false;
        _refDataError = true;
      });
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
      if (!mounted) return;
      setState(() {
        _usernameAvailable = !exists;
        _checkingUsername = false;
      });
    } catch (error) {
      logger.e('Username check failed: $error');
      if (!mounted) return;
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);

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

    return AuthScaffold(
      topLabel: 'Create Account',
      title: Text(
        'Join Flixie',
        style: textTheme.displaySmall?.copyWith(
          color: FlixieColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      subtitle: 'Create your account to get started',
      onBack: () => context.pop(),
      cardPadding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      cardChild: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: AuthTextField(
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
                  child: AuthTextField(
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
            Focus(
              onFocusChange: (hasFocus) {
                if (!hasFocus) {
                  _checkUsernameAvailability();
                }
              },
              child: AuthTextField(
                controller: _usernameController,
                label: 'Username',
                prefixIcon: Icons.alternate_email_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onChanged: (_) {
                  if (_usernameAvailable != null) {
                    setState(() => _usernameAvailable = null);
                  }
                },
                suffixIcon: _buildUsernameSuffix(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a username.';
                  }
                  if (value.trim().length < 3) {
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
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email.';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
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
                  return 'Please enter a password.';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: IconButton(
                tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                onPressed: () => setState(
                  () => _obscureConfirm = !_obscureConfirm,
                ),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: FlixieColors.light,
                ),
              ),
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
            const SizedBox(height: 18),
            if (_loadingRefData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_refDataError)
              _buildRefDataErrorRow(onRetry: _loadReferenceData)
            else ...[
              _buildDropdownField<Language>(
                items: _languages,
                selectedItem: _selectedLanguage,
                hintText: 'Select Language',
                itemLabel: (language) => language.name,
                onChanged: (language) => setState(() {
                  _selectedLanguage = language;
                  _languageTouched = true;
                }),
                errorText: _selectedLanguage == null &&
                        (_languageTouched || _submitAttempted)
                    ? 'Please select a language.'
                    : null,
              ),
              const SizedBox(height: 14),
              _buildDropdownField<Country>(
                items: _countries,
                selectedItem: _selectedCountry,
                hintText: 'Select Country',
                itemLabel: (country) => country.name,
                searchable: true,
                onChanged: (country) => setState(() {
                  _selectedCountry = country;
                  _countryTouched = true;
                }),
                errorText: _selectedCountry == null &&
                        (_countryTouched || _submitAttempted)
                    ? 'Please select a country.'
                    : null,
              ),
              if (_genres.isNotEmpty) ...[
                const SizedBox(height: 18),
                ..._buildGenrePicker(textTheme),
              ],
            ],
            const SizedBox(height: 22),
            AuthPrimaryButton(
              label: 'Create Account',
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: textTheme.bodyMedium?.copyWith(
                    color: FlixieColors.light,
                  ),
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

  Widget _buildDropdownField<T>({
    required List<T> items,
    required T? selectedItem,
    required String hintText,
    required String Function(T item) itemLabel,
    required ValueChanged<T?> onChanged,
    String? errorText,
    bool searchable = false,
  }) {
    final fillColor = const Color(0xFF0E1E35).withValues(alpha: 0.86);
    final textStyle = const TextStyle(
      color: FlixieColors.textPrimary,
      fontSize: 16,
    );
    final hintStyle = TextStyle(
      color: FlixieColors.light.withValues(alpha: 0.86),
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    final decoration = CustomDropdownDecoration(
      closedFillColor: fillColor,
      expandedFillColor: FlixieColors.surfaceElevated,
      closedBorder: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      expandedBorder: Border.all(color: FlixieColors.primaryTint),
      searchFieldDecoration: SearchFieldDecoration(fillColor: fillColor),
    );

    Widget dropdown;
    if (searchable) {
      dropdown = DropdownFlutter<T>.search(
        items: items,
        initialItem: selectedItem,
        hintText: hintText,
        onChanged: onChanged,
        headerBuilder: (context, item, _) => Text(
          itemLabel(item),
          style: textStyle,
        ),
        listItemBuilder: (context, item, isSelected, _) => Text(
          itemLabel(item),
          style: textStyle.copyWith(
            color:
                isSelected ? FlixieColors.primaryTint : FlixieColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        decoration: decoration,
      );
    } else {
      dropdown = DropdownFlutter<T>(
        items: items,
        initialItem: selectedItem,
        hintText: hintText,
        onChanged: onChanged,
        headerBuilder: (context, item, _) => Text(
          itemLabel(item),
          style: textStyle,
        ),
        listItemBuilder: (context, item, isSelected, _) => Text(
          itemLabel(item),
          style: textStyle.copyWith(
            color:
                isSelected ? FlixieColors.primaryTint : FlixieColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        decoration: decoration,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: FlixieColors.textPrimary,
                  displayColor: FlixieColors.textPrimary,
                ),
            hintColor: hintStyle.color,
          ),
          child: dropdown,
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: FlixieColors.danger,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRefDataErrorRow({required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlixieColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: FlixieColors.danger, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Failed to load options.',
              style: TextStyle(color: FlixieColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGenrePicker(TextTheme textTheme) {
    return [
      Row(
        children: [
          Text(
            'Favourite Genres',
            style: textTheme.titleMedium?.copyWith(
              color: FlixieColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(optional)',
            style: textTheme.bodySmall?.copyWith(color: FlixieColors.light),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _genres.map((genre) {
          final selected = _selectedGenreIds.contains(genre.id);
          return AuthChip(
            label: genre.name,
            selected: selected,
            onTap: () => setState(() {
              if (selected) {
                _selectedGenreIds.remove(genre.id);
              } else {
                _selectedGenreIds.add(genre.id);
              }
            }),
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
