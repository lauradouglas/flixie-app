import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingServicesStep extends StatelessWidget {
  const OnboardingServicesStep(
      {super.key,
      required this.controller,
      required this.search,
      required this.onCountry});
  final OnboardingController controller;
  final TextEditingController search;
  final VoidCallback onCountry;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _watching(context));
  List<Widget> _watching(BuildContext context) => [
        if (controller.loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          Row(children: [
            if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
              const Text('Country'),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton(
              onPressed: controller.busy || controller.countries.isEmpty
                  ? null
                  : onCountry,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Row(children: [
                Expanded(
                    child: Text(controller.country?.name ?? 'Select country')),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ]),
            )),
          ]),
          if (controller.country == null) ...[
            const SizedBox(height: 8),
            const Text(
                'Watch options vary by country. Choose yours to add your services.'),
          ],
          if (controller.error != null)
            TextButton(
                onPressed: controller.load, child: const Text('Retry setup')),
          const SizedBox(height: 8),
          if (controller.country != null) ...[
            const SizedBox(height: 8),
            Text('Your services',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
                controller: search,
                onChanged: controller.changeProviderQuery,
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    labelText: 'Search streaming services',
                    prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 12),
            for (final provider in controller.visibleProviders)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Material(
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  color: controller.selectedProviders.contains(provider.id)
                      ? context.colors.surfaceElevated
                      : context.colors.background,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: CheckboxListTile.adaptive(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: controller.selectedProviders.contains(provider.id),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: provider.logoPath.isEmpty
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(Icons.tv_outlined))
                          : Image.network(provider.logoUrl,
                              width: 36,
                              height: 36,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(Icons.tv_outlined))),
                    ),
                    title: Text(provider.providerName),
                    onChanged: controller.busy
                        ? null
                        : (selected) => controller.selectProvider(
                            provider.id, selected == true),
                  ),
                ),
              ),
            if (controller.visibleProviders.isEmpty)
              const Text(
                  'No matching services. You can continue without selecting one.'),
            TextButton(
                onPressed: controller.busy ? null : controller.clearProviders,
                child: const Text('I don’t use streaming services')),
          ],
        ],
      ];
}
