import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

const Set<String> _unsupportedGenreNames = {
  'action & adventure',
  'kids',
  'news',
  'reality',
  'sci-fi & fantasy',
  'soap',
  'talk',
  'tv movie',
  'war & politics',
};
final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

List<Genre> filterSupportedGenres(List<Genre> genres) {
  return genres
      .where(
        (genre) => !_unsupportedGenreNames.contains(
          genre.name.trim().toLowerCase(),
        ),
      )
      .toList(growable: false);
}

enum PasswordStrengthLevel { weak, medium, strong }

PasswordStrengthLevel evaluatePasswordStrength(String password) {
  var score = 0;
  if (password.length >= 8) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;

  if (score >= 3) return PasswordStrengthLevel.strong;
  if (score >= 2) return PasswordStrengthLevel.medium;
  return PasswordStrengthLevel.weak;
}

bool isValidEmailFormat(String value) {
  return _emailPattern.hasMatch(value.trim());
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.topLabel,
    required this.title,
    required this.subtitle,
    required this.cardChild,
    this.cardPadding = const EdgeInsets.all(24),
    this.onBack,
  });

  final String topLabel;
  final Widget title;
  final String subtitle;
  final Widget cardChild;
  final EdgeInsetsGeometry cardPadding;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textTheme = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final horizontalPadding = size.width > 700
        ? size.width * 0.24
        : size.width > 500
            ? 36.0
            : 20.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    24 + (viewInsets.bottom * 0.2),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 8,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0, end: 1),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 18),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (onBack != null) ...[
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _AuthBackButton(onPressed: onBack),
                                ),
                                const SizedBox(height: 20),
                              ],
                              Text(
                                topLabel,
                                style: textTheme.headlineSmall?.copyWith(
                                  color: FlixieColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              title,
                              const SizedBox(height: 14),
                              Text(
                                subtitle,
                                style: textTheme.titleMedium?.copyWith(
                                  color: FlixieColors.light
                                      .withValues(alpha: 0.92),
                                  height: 1.35,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 28),
                              AuthCard(
                                padding: cardPadding,
                                child: cardChild,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: FlixieColors.tabBarBorder.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );
  }
}

class AuthGradientBrand extends StatelessWidget {
  const AuthGradientBrand(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFB388FF),
          FlixieColors.primary,
          Color(0xFF6F45FF),
        ],
      ).createShader(bounds),
      child: Text(
        text,
        style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: controller,
      label: label,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
    );
  }
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({
    super.key,
    required this.password,
  });

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = evaluatePasswordStrength(password);
    final activeSegments = switch (strength) {
      PasswordStrengthLevel.weak => 1,
      PasswordStrengthLevel.medium => 2,
      PasswordStrengthLevel.strong => 4,
    };
    final label = switch (strength) {
      PasswordStrengthLevel.weak => 'Weak',
      PasswordStrengthLevel.medium => 'Medium',
      PasswordStrengthLevel.strong => 'Strong',
    };
    final color = switch (strength) {
      PasswordStrengthLevel.weak => FlixieColors.danger,
      PasswordStrengthLevel.medium => FlixieColors.warning,
      PasswordStrengthLevel.strong => FlixieColors.success,
    };

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (index) {
              final active = index < activeSegments && password.isNotEmpty;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: active
                        ? color
                        : FlixieColors.tabBarBorder.withValues(alpha: 0.8),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          password.isEmpty ? 'Weak' : label,
          style: TextStyle(
            color: password.isEmpty ? FlixieColors.light : color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      validator: widget.validator,
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: FlixieColors.light,
        ),
      ),
    );
  }
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (_hasFocus)
              BoxShadow(
                color: FlixieColors.primary.withValues(alpha: 0.14),
                blurRadius: 22,
                spreadRadius: 1,
              ),
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          style: const TextStyle(
            color: FlixieColors.textPrimary,
            fontSize: 16,
          ),
          decoration: buildAuthInputDecoration(
            label: widget.label,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            isFocused: _hasFocus,
          ),
        ),
      ),
    );
  }
}

InputDecoration buildAuthInputDecoration({
  required String label,
  IconData? prefixIcon,
  Widget? suffixIcon,
  bool isFocused = false,
}) {
  return InputDecoration(
    labelText: label,
    hintText: label,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    hintStyle: TextStyle(
      color: FlixieColors.light.withValues(alpha: 0.86),
      fontSize: 16,
    ),
    labelStyle: TextStyle(
      color: FlixieColors.light.withValues(alpha: 0.86),
      fontSize: 16,
    ),
    filled: true,
    fillColor: (isFocused
            ? FlixieColors.surfaceElevated
            : FlixieColors.tabBarBackgroundFocused)
        .withValues(alpha: 0.9),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(
            prefixIcon,
            size: 22,
            color: isFocused ? FlixieColors.primaryTint : FlixieColors.medium,
          ),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: FlixieColors.tabBarBorder.withValues(alpha: 0.9),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(
        color: FlixieColors.primary,
        width: 1.6,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: FlixieColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: FlixieColors.danger, width: 1.4),
    ),
  );
}

class AuthPrimaryButton extends StatefulWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: enabled
                  ? const [
                      Color(0xFFB06BFF),
                      FlixieColors.primary,
                      Color(0xFF5A36E6),
                    ]
                  : [
                      FlixieColors.primary.withValues(alpha: 0.45),
                      FlixieColors.primary.withValues(alpha: 0.35),
                    ],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: FlixieColors.primary.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: enabled ? widget.onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white70,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthChip extends StatelessWidget {
  const AuthChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? FlixieColors.primary
                  : FlixieColors.tabBarBorder.withValues(alpha: 0.9),
              width: selected ? 1.4 : 1,
            ),
            color: selected
                ? FlixieColors.primary.withValues(alpha: 0.16)
                : FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.9),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: FlixieColors.primary.withValues(alpha: 0.14),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? FlixieColors.textPrimary : FlixieColors.lightTint,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AuthChip(label: label, selected: selected, onTap: onTap);
  }
}

class MovieSelectionCard extends StatelessWidget {
  const MovieSelectionCard({
    super.key,
    required this.movie,
    required this.onRemove,
    this.posterBaseUrl = 'https://image.tmdb.org/t/p/w185',
  });

  final MovieShort movie;
  final VoidCallback onRemove;
  final String posterBaseUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 82,
            height: 122,
            child: movie.poster == null
                ? Container(
                    color: FlixieColors.surfaceElevated,
                    child: const Icon(Icons.movie_outlined,
                        color: FlixieColors.light),
                  )
                : CachedNetworkImage(
                    imageUrl: '$posterBaseUrl${movie.poster}',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: FlixieColors.surfaceElevated,
                      child: const Icon(Icons.movie_outlined,
                          color: FlixieColors.light),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class MovieSearchSheet extends StatefulWidget {
  const MovieSearchSheet({
    super.key,
    required this.searchMovies,
    this.title = 'Search for movies',
  });

  final Future<List<MovieShort>> Function(String query) searchMovies;
  final String title;

  @override
  State<MovieSearchSheet> createState() => _MovieSearchSheetState();
}

class _MovieSearchSheetState extends State<MovieSearchSheet> {
  final _controller = TextEditingController();
  List<MovieShort> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final movies = await widget.searchMovies(query);
      if (!mounted) return;
      setState(() => _results = movies);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlixieColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _controller,
              label: 'Search for movies...',
              prefixIcon: Icons.search_rounded,
              onChanged: _search,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final movie = _results[index];
                        return ListTile(
                          title: Text(
                            movie.name,
                            style: const TextStyle(
                                color: FlixieColors.textPrimary),
                          ),
                          onTap: () => Navigator.of(context).pop(movie),
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

class OnboardingProgressIndicator extends StatelessWidget {
  const OnboardingProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 8),
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF9B6DFF), Color(0xFFB58DFF)],
                    )
                  : null,
              color: active
                  ? null
                  : FlixieColors.tabBarBorder.withValues(alpha: 0.75),
            ),
          ),
        );
      }),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AuthPrimaryButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FlixieColors.textPrimary,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label),
    );
  }
}

class _AuthBackButton extends StatelessWidget {
  const _AuthBackButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: FlixieColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF170B32),
            Color(0xFF28104D),
            Color(0xFF120821),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _buildGlow(
              color: FlixieColors.primary.withValues(alpha: 0.22),
              size: 320,
            ),
          ),
          Positioned(
            top: 180,
            left: -110,
            child: _buildGlow(
              color: const Color(0xFF6D35A8).withValues(alpha: 0.30),
              size: 280,
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: _buildGlow(
              color: FlixieColors.primaryTint.withValues(alpha: 0.16),
              size: 260,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow({required Color color, required double size}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
