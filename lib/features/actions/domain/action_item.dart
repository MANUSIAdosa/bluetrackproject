/// A conservation action listed on the Action Agenda (Aksi).
///
/// Named [ActionItem] because Flutter's widgets library already exports an
/// `Action` class. The model stays UI-agnostic so the mock repository can be
/// replaced by an API client without touching the cards or the detail page.
class ActionItem {
  const ActionItem({
    required this.id,
    required this.title,
    required this.type,
    required this.startsAt,
    required this.endsAt,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.quota,
    required this.registered,
    required this.organizerName,
    required this.organizerVerified,
    required this.imageAsset,
    this.organizerId,
    this.description = '',
    this.meetingPoint = '',
    this.equipment = const [],
  });

  final String id;
  final String title;
  final ActionType type;
  final DateTime startsAt;
  final DateTime endsAt;
  final String locationName;
  final double latitude;
  final double longitude;
  final int quota;
  final int registered;
  final String organizerName;
  final bool organizerVerified;
  final String imageAsset;

  /// Organization profile id used by the organizer section. Null keeps the
  /// section visible but non-navigable when a mock action has no matching
  /// profile yet.
  final String? organizerId;

  /// Long description shown on the detail page.
  final String description;

  /// Where participants gather before the activity starts.
  final String meetingPoint;

  /// Items participants should bring.
  final List<String> equipment;

  /// True when no more participants can register.
  bool get isFull => registered >= quota;

  /// True once the activity has finished.
  bool hasEndedAt(DateTime now) => !now.isBefore(endsAt);

  /// Registration is closed for full, started, or finished actions.
  bool canRegisterAt(DateTime now) =>
      !isFull && now.isBefore(startsAt) && now.isBefore(endsAt);

  /// The status shown on the detail page and on the agenda card.
  ///
  /// Order matters: a finished activity is [ActionStatus.ended] even when its
  /// quota is also full, and a full quota keeps [ActionStatus.full] while the
  /// activity runs (it is the reason registration is closed). [ActionStatus
  /// .ongoing] only covers the window where registration used to report a
  /// misleading "open" state.
  ActionStatus statusAt(DateTime now) {
    if (hasEndedAt(now)) return ActionStatus.ended;
    if (isFull) return ActionStatus.full;
    if (!now.isBefore(startsAt)) return ActionStatus.ongoing;
    return ActionStatus.open;
  }

  /// Copy with a different live participant count.
  ///
  /// Used by the mock repository, which reflects this session's registrations
  /// in the returned count the way a real API would. Nothing else needs to
  /// mutate an action.
  ActionItem copyWith({int? registered}) {
    return ActionItem(
      id: id,
      title: title,
      type: type,
      startsAt: startsAt,
      endsAt: endsAt,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      quota: quota,
      registered: registered ?? this.registered,
      organizerName: organizerName,
      organizerVerified: organizerVerified,
      imageAsset: imageAsset,
      organizerId: organizerId,
      description: description,
      meetingPoint: meetingPoint,
      equipment: equipment,
    );
  }

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    final date = json['date'] as String;
    return ActionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      type: ActionType.fromId(json['type'] as String),
      startsAt: DateTime.parse('$date ${json['startTime']}'),
      endsAt: DateTime.parse('$date ${json['endTime']}'),
      locationName: json['locationName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      quota: json['quota'] as int,
      registered: json['registered'] as int,
      organizerName: json['organizerName'] as String,
      organizerVerified: json['organizerVerified'] as bool,
      organizerId: json['organizerId'] as String?,
      imageAsset: json['imageAsset'] as String,
      description: json['description'] as String? ?? '',
      meetingPoint: json['meetingPoint'] as String? ?? '',
      equipment: (json['equipment'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }
}

/// Registration/display status of an action.
///
/// [ongoing] is derived from the existing start/end times: the activity has
/// started but not finished, so registration is already closed.
enum ActionStatus { open, full, ongoing, ended }

/// Kinds of action shown on the agenda.
///
/// [id] is the stable value used in `assets/mock/actions.json` and in the
/// localization key `action.type.<id>`; the enum name never reaches the UI.
enum ActionType {
  beachCleanup('beach_cleanup'),
  coralRestoration('coral_restoration'),
  mangrovePlanting('mangrove_planting'),
  wildlifeMonitoring('wildlife_monitoring'),
  education('education');

  const ActionType(this.id);

  final String id;

  /// Falls back to [education] so one unknown mock value cannot break the
  /// whole agenda; the card still shows a readable type label.
  static ActionType fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return education;
  }
}
