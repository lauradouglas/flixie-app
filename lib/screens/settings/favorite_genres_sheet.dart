import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/genre.dart';
import '../../providers/auth_provider.dart';
import '../../services/reference_data_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class FavoriteGenresSheet extends StatefulWidget {
  const FavoriteGenresSheet({
    super.key,
    required this.userId,
    required this.currentGenres,
  });

  final String userId;
  final List<dynamic> currentGenres;

  @override
  State<FavoriteGenresSheet> createState() => _FavoriteGenresSheetState();
}

class _FavoriteGenresSheetState extends State<FavoriteGenresSheet> {
  List<Genre> _allGenres = [];
  late Set<int> _selectedIds;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Populate current selections from the user's existing favoriteGenres
    _selectedIds = widget.currentGenres.map<int>((item) {
      if (item is Map<String, dynamic>) {
        final nested = item['genre'];
        if (nested is Map<String, dynamic>) return nested['id'] as int;
        return (item['id'] ?? item['genreId']) as int;
      }
      return item as int;
    }).toSet();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await ReferenceDataService.getGenres();
      if (mounted) {
        setState(() {
          _allGenres = genres;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserService.addFavoriteGenres(widget.userId, _selectedIds.toList());
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUserData();
      if (!mounted) return;
      // Capture messenger before pop — context is deactivated after pop()
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Favourite genres updated.'),
          backgroundColor: FlixieColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save genres. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
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
              'Favourite Genres',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select the genres you enjoy most.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: FlixieColors.primary))
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allGenres.map((genre) {
                      final selected = _selectedIds.contains(genre.id);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedIds.remove(genre.id);
                          } else {
                            _selectedIds.add(genre.id);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? FlixieColors.primary.withValues(alpha: 0.2)
                                : FlixieColors.tabBarBackground,
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
                                  color: selected
                                      ? FlixieColors.primary
                                      : FlixieColors.light,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
