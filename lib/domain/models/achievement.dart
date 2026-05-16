/// Achievement catalog entry from `public.achievements`.
class Achievement {
  const Achievement({
    required this.code,
    required this.name,
    required this.description,
    required this.rarity,
    required this.category,
    this.icon,
    this.threshold,
  });

  final String code;
  final String name;
  final String description;
  final String? icon;
  final String rarity;       // common | rare | epic | legendary
  final String category;     // distance | streak | pr | social | special
  final double? threshold;   // for distance/streak categories

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        code: j['code'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        icon: j['icon'] as String?,
        rarity: j['rarity'] as String,
        category: j['category'] as String,
        threshold: (j['threshold'] as num?)?.toDouble(),
      );
}

/// A user's unlocked achievement (join with [Achievement] for display).
class UnlockedAchievement {
  const UnlockedAchievement({
    required this.code,
    required this.unlockedAt,
    this.activityId,
  });

  final String code;
  final DateTime unlockedAt;
  final String? activityId;

  factory UnlockedAchievement.fromJson(Map<String, dynamic> j) =>
      UnlockedAchievement(
        code: j['achievement_code'] as String,
        unlockedAt: DateTime.parse(j['unlocked_at'] as String),
        activityId: j['activity_id'] as String?,
      );
}
