import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'search_mode.dart';

class SearchQueryField extends StatelessWidget {
  const SearchQueryField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.mode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final SearchMode mode;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: context.colors.white),
        decoration: InputDecoration(
          hintText: mode.hintText,
          hintStyle: TextStyle(color: context.colors.medium),
          prefixIcon: Icon(Icons.search_rounded, color: context.colors.medium),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: Icon(Icons.close_rounded, color: context.colors.medium),
                  onPressed: onClear,
                ),
            ],
          ),
          filled: true,
          fillColor: context.colors.tabBarBackgroundFocused,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: FlixieColors.primary),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
      ),
    );
  }
}

class SearchModeSelector extends StatelessWidget {
  const SearchModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final SearchMode value;
  final ValueChanged<SearchMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final modes = [
      SearchMode.all,
      SearchMode.movies,
      SearchMode.shows,
      SearchMode.people,
      // TODO: Re-add Studios when its search experience is ready.
      // SearchMode.companies,
      SearchMode.collections,
    ];

    return SizedBox(
      height: 42 + MediaQuery.textScalerOf(context).scale(16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        itemCount: modes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final selected = mode == value;
          return FlixiePill.choice(
            selected: selected,
            showCheckmark: false,
            label: Text(mode.label),
            avatar: mode == SearchMode.all
                ? null
                : Icon(
                    mode.icon,
                    size: 17,
                    color: selected ? Colors.white : context.colors.medium,
                  ),
            onSelected: (_) => onChanged(mode),
          );
        },
      ),
    );
  }
}
