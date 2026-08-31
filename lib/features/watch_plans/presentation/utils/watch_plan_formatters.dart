const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatWatchPlanDate(String? iso) {
  final value = DateTime.tryParse(iso ?? '');
  if (value == null) return '';
  return '${value.day} ${_months[value.month - 1]} ${value.year}';
}

String formatWatchPlanDateTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '';
  final local = value.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final date = DateTime(local.year, local.month, local.day);
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'pm' : 'am';
  final time = '$hour:$minute$suffix';
  if (date == today) return 'Today at $time';
  if (date == today.add(const Duration(days: 1))) {
    return 'Tomorrow at $time';
  }
  return '${local.day} ${_months[local.month - 1]}, $time';
}

String formatWatchPlanLocation(String? location) {
  final trimmed = location?.trim() ?? '';
  return trimmed.isEmpty ? 'Location undecided' : trimmed;
}
