import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/social_auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';

class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({super.key, this.connect = false, this.onSignedIn});

  final bool connect;
  final VoidCallback? onSignedIn;

  Future<void> _submit(
      BuildContext context, SocialAuthProvider provider) async {
    final auth = context.read<AuthProvider>();
    final success = connect
        ? await auth.connectSocialProvider(provider)
        : await auth.signInWithSocialProvider(provider);
    if (!context.mounted) return;
    if (success) {
      if (connect) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.success,
          content:
              Text('${provider.label} connected. You can use it to sign in.'),
        ));
      } else if (onSignedIn != null) {
        onSignedIn!();
      } else {
        context.go(auth.needsSocialProfile ? '/auth/signup' : '/');
      }
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: Text(auth.errorMessage!),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in SocialAuthProvider.available) ...[
          if (provider != SocialAuthProvider.available.first)
            const SizedBox(height: 12),
          OutlinedButton(
            onPressed: auth.isLoading ||
                    (connect &&
                        SocialAuthProvider.values.any(auth.isProviderConnected))
                ? null
                : () => _submit(context, provider),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1F1F1F),
              disabledForegroundColor: const Color(0xFF5F6368),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: Color(0xFF747775)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              children: [
                if (provider == SocialAuthProvider.apple)
                  const Icon(Icons.apple, size: 22)
                else
                  SvgPicture.string(_googleMark, width: 20, height: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                  connect
                      ? (auth.isProviderConnected(provider)
                          ? '${provider.label} connected'
                          : 'Connect with ${provider.label}')
                      : 'Continue with ${provider.label}',
                  textAlign: TextAlign.center,
                )),
                const SizedBox(width: 20),
              ],
            ),
          ),
        ],
        if (auth.isLoading) ...[
          const SizedBox(height: 12),
          const Center(
              child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, semanticsLabel: 'Connecting'),
          )),
        ],
      ],
    );
  }
}

// Google's standard multicolour G mark, kept at its original proportions.
const _googleMark =
    '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6C44.4 38.03 46.98 31.87 46.98 24.55z"/>
<path fill="#FBBC05" d="M10.53 28.59C10.05 27.14 9.77 25.6 9.77 24s.28-3.14.77-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.91-5.8l-7.73-6c-2.15 1.45-4.92 2.3-8.18 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>''';
