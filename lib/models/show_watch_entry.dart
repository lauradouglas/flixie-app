import 'package:flixie_app/models/show.dart';

class ShowWatchEntry {
  final String id;
  final String userId;
  final int showId;
  final String? watchedAt;
  final double? rating;
  final String? notes;
  final bool removed;
  final String? createdAt;
  final String? updatedAt;
  final TvShow? show;

  const ShowWatchEntry({
    required this.id,
    required this.userId,
    required this.showId,
    this.watchedAt,
    this.rating,
    this.notes,
    required this.removed,
    this.createdAt,
    this.updatedAt,
    this.show,
  });

  factory ShowWatchEntry.fromJson(Map<String, dynamic> json) {
    return ShowWatchEntry(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      showId: _parseInt(json['showId']) ?? 0,
      watchedAt: json['watchedAt'] as String? ?? json['createdAt'] as String?,
      rating: _parseDouble(json['rating']),
      notes: json['notes'] as String?,
      removed: json['removed'] as bool? ?? false,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      show: json['show'] is Map<String, dynamic>
          ? TvShow.fromJson(json['show'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'showId': showId,
      'watchedAt': watchedAt,
      'rating': rating,
      'notes': notes,
      'removed': removed,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (show != null) 'show': show!.toJson(),
    };
  }
}

class LogShowWatchRequest {
  final int showId;
  final String? watchedAt;
  final double? rating;
  final String? notes;

  const LogShowWatchRequest({
    required this.showId,
    this.watchedAt,
    this.rating,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'showId': showId,
      'watchedAt': watchedAt,
      'rating': rating,
      'notes': notes,
    };
  }
}

class UpdateShowWatchRequest {
  final double? rating;
  final String? notes;
  final String? watchedAt;

  const UpdateShowWatchRequest({
    this.rating,
    this.notes,
    this.watchedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'watchedAt': watchedAt,
      'rating': rating,
      'notes': notes,
    };
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
