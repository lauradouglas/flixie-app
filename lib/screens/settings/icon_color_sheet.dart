import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/icon_color.dart';
import '../../providers/auth_provider.dart';
import '../../services/reference_data_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class IconColorSheet extends StatefulWidget {
  const IconColorSheet({
    super.key,
    required this.userId,
    required this.currentColorId,
  });

  final String userId;
  final int currentColorId;

  @override
  State<IconColorSheet> createState() => _IconColorSheetState();
}

class _IconColorSheetState extends State<IconColorSheet> {
  List<IconColor> _colors = [];
  late int _selectedId;
  bool _loading = true;
  int? _savingId; // id currently being saved, disables all others

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentColorId;
    _loadColors();
  }

  Future<void> _loadColors() async {
    try {
      final colors = await ReferenceDataService.getColors();
      if (mounted) {
        setState(() {
          _colors = colors;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(IconColor color) async {
    if (_savingId != null || color.id == _selectedId) return;
    // Capture context-dependent objects before any await
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingId = color.id);
    try {
      final updatedUser =
          await UserService.updateIconColor(widget.userId, color.id);
      if (!mounted) return;
      auth.updateCachedUser(updatedUser);
      setState(() {
        _selectedId = color.id;
        _savingId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingId = null);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update colour. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value =
        int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return Color(value ?? 0xFFFFFFFF);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
              'Avatar Colour',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a colour to apply it to your avatar.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: FlixieColors.primary))
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _colors.map((c) {
                  final isSelected = c.id == _selectedId;
                  final isSaving = _savingId == c.id;
                  final isDisabled = _savingId != null && !isSaving;
                  final circleColor = _parseHex(c.hexCode);

                  return GestureDetector(
                    onTap: isDisabled ? null : () => _select(c),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: isDisabled ? 0.35 : 1.0,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Colour circle
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: circleColor,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: circleColor.withValues(
                                              alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            // Spinner while saving this colour
                            if (isSaving)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            // Check mark when selected
                            else if (isSelected)
                              const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
