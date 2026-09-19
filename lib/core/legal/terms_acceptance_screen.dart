import 'package:flixie_app/features/settings/presentation/widgets/delete_account_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'terms_agreement_field.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key});
  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  final _form = GlobalKey<FormState>();
  bool _loading = true;
  bool _checked = false;
  bool _needsAgreement = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check({bool accept = false}) async {
    if (!mounted) return;
    if (accept && (!_checked || !_form.currentState!.validate())) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final verified =
          await context.read<AuthProvider>().verifyTerms(accept: accept);
      if (mounted && !verified) {
        setState(() => _needsAgreement = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not confirm your agreement. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('Terms of Use')),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loading && !_needsAgreement)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          if (_needsAgreement) ...[
                            Text('Before you continue',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            const Text(
                                'Please read and agree to the Terms of Use to continue using Flixie.'),
                            const SizedBox(height: 16),
                            TermsAgreementField(
                                onChanged: (value) =>
                                    setState(() => _checked = value)),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed: _checked && !_loading
                                    ? () => _check(accept: true)
                                    : null,
                                child: const Text('Agree and continue')),
                          ],
                          if (_error != null) ...[
                            Text(_error!, semanticsLabel: _error),
                            TextButton(
                                onPressed: () => _check(),
                                child: const Text('Try again')),
                          ],
                          TextButton(
                              onPressed: () =>
                                  context.read<AuthProvider>().signOut(),
                              child: const Text('Sign out')),
                        ],
                        const SizedBox(height: 24),
                        const DeleteAccountButton(),
                      ]),
                )),
          ))),
        ),
      );
}
