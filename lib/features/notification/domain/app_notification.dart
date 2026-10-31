import 'dart:math';

/// P13 — one notification shown in `/notifications` and counted by the shell
/// badge.
///
/// `time` is resolved at load time: the mock asset stores `minutesAgo` so the
/// three time groups ( Hari ini / Minggu ini / Lebih lama ) stay observable in
/// a demo at any point in time. Grouping itself is always computed downstream
/// against `DateTime.now()` — see the page — never from a stored category.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    required this.read,
    required this.route,
  });

  final String id;

  /// Which of the three notification kinds this is.
  final NotificationType type;

  final String title;

  /// Short single-sentence description shown under the title.
  final String body;

  final DateTime time;

  final bool read;

  /// Registered route the app navigates to when the item is tapped.
  final String route;

  @override
  bool operator ==(Object other) =>
      other is AppNotification &&
      other.id == id &&
      other.type == type &&
      other.title == title &&
      other.body == body &&
      other.time == time &&
      other.read == read &&
      other.route == route;

  @override
  int get hashCode => Object.hash(id, type, title, body, time, read, route);

  /// Parses one notification object from the mock asset.
  ///
  /// `minutesAgo` (relative to the current time) and `time` (ISO 8601) are
  /// both accepted so a future API source can switch to absolute timestamps
  /// without a model change. Title/body resolve localized keys
  /// (`titleId`/`titleEn`, `bodyId`/`bodyEn`) by [lang], falling back to the
  /// plain `title`/`body` keys a future API may already serve pre-localized.
  /// Unknown types never crash the list — they map to
  /// [NotificationType.reportStatus], the app's default kind.
  /// TODO(P13, minggu 12–13): reload the list when the app locale changes, so
  /// switching language re-resolves the localized copy.
  factory AppNotification.fromJson(
    Map<String, dynamic> json,
    DateTime now, {
    String lang = 'id',
  }) {
    final suffix = lang == 'en' ? 'En' : 'Id';
    return AppNotification(
      id: json['id']! as String,
      type: NotificationType.tryParse(json['type'] as String?),
      title: (json['title$suffix'] ?? json['title'])! as String,
      body: (json['body$suffix'] ?? json['body'])! as String,
      time: json.containsKey('minutesAgo')
          ? now.subtract(
              Duration(minutes: max(0, (json['minutesAgo'] as num).toInt())),
            )
          : json.containsKey('time')
              ? DateTime.parse(json['time']! as String)
              : now,
      read: json['read']! as bool,
      route: json['route']! as String,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        // Canonical Dart enum name (`reportStatus`); `fromJson` accepts both
        // this and the asset's snake_case spelling.
        'type': type.name,
        'title': title,
        'body': body,
        'time': time.toIso8601String(),
        'read': read,
        'route': route,
      };
}

/// The three kinds of notification defined by P13.
enum NotificationType {
  reportStatus,
  actionReminder,
  locationUpdate;

  /// Accepts the asset's snake_case spelling and the canonical Dart name.
  /// Unknown values fall back to [reportStatus] so a bad mock row can never
  /// crash the whole list.
  static NotificationType tryParse(String? raw) =>
      switch (raw) {
        'report_status' || 'reportStatus' => reportStatus,
        'action_reminder' || 'actionReminder' => actionReminder,
        'location_update' || 'locationUpdate' => locationUpdate,
        _ => reportStatus,
      };
}
