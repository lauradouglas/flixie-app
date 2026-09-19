import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/flixie_prompt_sheet.dart';

class LogoutSheet extends StatefulWidget {
  const LogoutSheet({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends State<LogoutSheet> {
  bool _loggingOut = false;
  String? _error;

  Future<void> _signOut() async {
    if (_loggingOut) return;
    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      await widget.onSignOut();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loggingOut = false;
        _error = 'Could not finish logging out. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_loggingOut,
      child: FlixiePromptSheetContent(
        title: Text(
          _loggingOut ? 'Logging you out…' : 'Log Out',
          style: TextStyle(color: context.colors.white),
        ),
        content: _loggingOut
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Please wait…',
                        style: TextStyle(color: context.colors.light)),
                  ],
                ),
              )
            : Text(
                _error ?? 'Are you sure you want to log out?',
                style: TextStyle(color: context.colors.light),
              ),
        actions: _loggingOut
            ? const []
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _signOut,
                  child: Text('Log Out',
                      style: TextStyle(color: context.colors.danger)),
                ),
              ],
      ),
    );
  }
}
