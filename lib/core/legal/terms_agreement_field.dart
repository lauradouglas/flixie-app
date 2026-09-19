import 'package:flutter/material.dart';

import 'terms_of_use_screen.dart';
import 'privacy_policy.dart';

/// Form validation also guards submission from the keyboard.
class TermsAgreementField extends StatelessWidget {
  const TermsAgreementField({super.key, this.onChanged});

  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: false,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => value == true
          ? null
          : 'Please agree to the Terms of Use to continue.',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: field.value ?? false,
            onChanged: (value) {
              field.didChange(value ?? false);
              onChanged?.call(value ?? false);
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I agree to the Terms of Use'),
          ),
          TextButton(
            onPressed: () => TermsOfUseScreen.open(context),
            child: const Text('Read Terms of Use'),
          ),
          TextButton(
            onPressed: () => openPrivacyPolicy(context),
            child: const Text('Privacy Policy'),
          ),
          if (field.hasError)
            Semantics(
              liveRegion: true,
              child: Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
