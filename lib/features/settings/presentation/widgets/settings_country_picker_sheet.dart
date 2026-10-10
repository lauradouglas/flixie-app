import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/country.dart';

class SettingsCountryPickerSheet extends StatefulWidget {
  const SettingsCountryPickerSheet(
      {super.key, required this.countries, this.selected});

  final List<Country> countries;
  final Country? selected;

  @override
  State<SettingsCountryPickerSheet> createState() =>
      SettingsCountryPickerSheetState();
}

class SettingsCountryPickerSheetState
    extends State<SettingsCountryPickerSheet> {
  final _searchController = TextEditingController();
  late List<Country> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.countries
          : widget.countries
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Country',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: true,
              style: TextStyle(color: context.colors.white),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                hintStyle: TextStyle(color: context.colors.medium),
                prefixIcon: Icon(Icons.search, color: context.colors.medium),
                filled: true,
                fillColor: context.colors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final country = _filtered[index];
                  final isSelected = country.id == widget.selected?.id;
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        country.name,
                        style: TextStyle(
                          color: isSelected
                              ? context.colors.primaryTint
                              : context.colors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded,
                              color: context.colors.primaryTint)
                          : null,
                      onTap: () => Navigator.of(context).pop(country),
                    ),
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
