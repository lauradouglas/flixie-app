import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/settings/data/reference_data_service.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_country_picker_sheet.dart';

/// Reuses the account country preference that drives cinema and provider regions.
Future<void> changeHomeCinemaCountry(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final user = auth.dbUser;
  if (user == null) return;
  bool current() => context.mounted && auth.dbUser?.id == user.id;
  try {
    final countries = await ReferenceDataService.getCountries();
    if (!context.mounted || !current()) return;
    final selected = await showModalBottomSheet<Country>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: context.colors.surface,
        builder: (sheetContext) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * .85),
            child: SingleChildScrollView(
                child: SettingsCountryPickerSheet(
                    countries: countries,
                    selected: countries
                        .where((c) => c.id == user.countryId)
                        .firstOrNull))));
    if (!context.mounted ||
        !current() ||
        selected == null ||
        selected.id == auth.dbUser?.countryId) {
      return;
    }
    await UserService.updateUserField(user.id, 'countryId', selected.id);
    if (!context.mounted || !current()) return;
    auth.updateCachedUser(auth.dbUser!
        .copyWith(countryId: selected.id, country: selected.toJson()));
  } catch (_) {
    if (context.mounted && current()) {
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content:
              const Text('Couldn’t update your country. Please try again.')));
    }
  }
}
