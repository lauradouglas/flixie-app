import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/genre.dart';
import '../../theme/app_theme.dart';

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

List<Genre> filterSupportedGenres(List<Genre> genres) {
  return genres
      .where(
        (genre) => !_unsupportedGenreNames.contains(
          genre.name.trim().toLowerCase(),
        ),
      )
      .toList(growable: false);
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
                              Align(
                                alignment: Alignment.centerLeft,
                                child: _AuthBackButton(onPressed: onBack),
                              ),
                              const SizedBox(height: 20),
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
            Color(0xFF061625),
            FlixieColors.background,
            Color(0xFF08111F),
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
              color: const Color(0xFF1B3B66).withValues(alpha: 0.34),
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
