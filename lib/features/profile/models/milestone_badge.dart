class MilestoneBadge {
  const MilestoneBadge(
      {required this.id,
      required this.target,
      required this.metal,
      required this.label,
      this.earned = false,
      this.displayOrder});
  final String id, metal, label;
  final int target;
  final bool earned;
  final int? displayOrder;
  factory MilestoneBadge.fromJson(Map<String, dynamic> json) => MilestoneBadge(
      id: json['id'] as String,
      target: (json['target'] as num).toInt(),
      metal: json['metal'] as String,
      label: json['label'] as String,
      earned: json['earned'] == true,
      displayOrder: (json['displayOrder'] as num?)?.toInt());
  static const examples = [
    MilestoneBadge(
        id: 'films_50', target: 50, metal: 'bronze', label: '50 films'),
    MilestoneBadge(
        id: 'films_100', target: 100, metal: 'silver', label: '100+ films'),
    MilestoneBadge(
        id: 'films_250', target: 250, metal: 'gold', label: '250+ films'),
    MilestoneBadge(
        id: 'films_500', target: 500, metal: 'purple', label: '500+ films'),
  ];
}
