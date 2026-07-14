import 'package:flutter/material.dart';

import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:flixie_app/features/settings/data/reference_data_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class WatchProvidersSheet extends StatefulWidget {
  const WatchProvidersSheet({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<WatchProvidersSheet> createState() => _WatchProvidersSheetState();
}

class _WatchProvidersSheetState extends State<WatchProvidersSheet> {
  final SettingsController _settingsController = SettingsController.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  List<WatchProvider> _providers = [];
  List<WatchProvider> _filteredProviders = [];
  Set<int> _selectedProviderIds = {};

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    try {
      final allProviders = await ReferenceDataService.getWatchProviders();

      final selectedProviders =
          await _settingsController.getUserWatchProviders(widget.userId);

      if (!mounted) return;

      setState(() {
        _providers = allProviders;
        _filteredProviders = allProviders;
        _selectedProviderIds = selectedProviders.map((p) => p.id).toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _toggleProvider(int providerId) {
    setState(() {
      if (_selectedProviderIds.contains(providerId)) {
        _selectedProviderIds.remove(providerId);
      } else {
        _selectedProviderIds.add(providerId);
      }
    });
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();

    setState(() {
      _filteredProviders = q.isEmpty
          ? _providers
          : _providers
              .where(
                  (provider) => provider.providerName.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      await _settingsController.updateUserWatchProviders(
        widget.userId,
        _selectedProviderIds.toList(),
      );

      if (!mounted) return;

      Navigator.pop(context);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Watch providers updated'),
          backgroundColor: FlixieColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update watch providers'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Watch Providers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_selectedProviderIds.length} selected',
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the streaming services you use. Flixie can then show what you can watch now.',
              style: TextStyle(
                color: FlixieColors.medium,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search providers...',
                hintStyle: const TextStyle(color: FlixieColors.medium),
                prefixIcon:
                    const Icon(Icons.search, color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FlixieColors.primary,
                      ),
                    )
                  : _filteredProviders.isEmpty
                      ? const Center(
                          child: Text(
                            'No providers found',
                            style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _filteredProviders.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final provider = _filteredProviders[index];
                            final selected =
                                _selectedProviderIds.contains(provider.id);

                            return InkWell(
                              onTap: () => _toggleProvider(provider.id),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? FlixieColors.primary
                                          .withValues(alpha: 0.18)
                                      : FlixieColors.tabBarBackgroundFocused,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? FlixieColors.primaryTint
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        provider.logoUrl,
                                        width: 42,
                                        height: 42,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: FlixieColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.tv_outlined,
                                            color: FlixieColors.medium,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        provider.providerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Checkbox(
                                      value: selected,
                                      onChanged: (_) =>
                                          _toggleProvider(provider.id),
                                      activeColor: FlixieColors.primary,
                                      checkColor: Colors.white,
                                      side: const BorderSide(
                                        color: FlixieColors.medium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Providers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
