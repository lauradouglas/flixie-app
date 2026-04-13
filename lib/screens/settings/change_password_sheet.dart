import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final error = await context
        .read<AuthProvider>()
        .updatePassword(_currentCtrl.text, _newCtrl.text);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated successfully.'),
        backgroundColor: FlixieColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1B3258),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
                'Change Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _PasswordField(
                controller: _currentCtrl,
                label: 'Current password',
                obscure: _currentObscure,
                onToggle: () =>
                    setState(() => _currentObscure = !_currentObscure),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _newCtrl,
                label: 'New password',
                obscure: _newObscure,
                onToggle: () => setState(() => _newObscure = !_newObscure),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmCtrl,
                label: 'Confirm new password',
                obscure: _confirmObscure,
                onToggle: () =>
                    setState(() => _confirmObscure = !_confirmObscure),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style:
                      const TextStyle(color: FlixieColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Password',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: FlixieColors.medium),
        filled: true,
        fillColor: FlixieColors.tabBarBorder,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: FlixieColors.medium,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
