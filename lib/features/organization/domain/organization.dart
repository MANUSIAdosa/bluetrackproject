/// Organization domain model (P05).
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.verified,
    required this.location,
    required this.establishedYear,
    required this.totalProjects,
    required this.totalDisbursed,
    required this.communitiesServed,
    required this.color,
    required this.email,
    required this.phone,
    required this.checklist,
  });

  final String id;
  final String name;
  final bool verified;
  final String location;
  final int establishedYear;
  final int totalProjects;
  final int totalDisbursed;
  final int communitiesServed;

  /// Hex color used as avatar placeholder.
  final String color;
  final String email;
  final String phone;
  final List<ChecklistItem> checklist;

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        name: json['name'] as String,
        verified: json['verified'] as bool? ?? false,
        location: json['location'] as String,
        establishedYear: json['establishedYear'] as int,
        totalProjects: json['totalProjects'] as int,
        totalDisbursed: json['totalDisbursed'] as int,
        communitiesServed: json['communitiesServed'] as int,
        color: json['color'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        checklist: (json['checklist'] as List<dynamic>)
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ChecklistItem {
  const ChecklistItem({required this.key, required this.done});

  /// Checklist key: legal | audit | field | finance (localized in the UI).
  final String key;
  final bool done;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        key: json['key'] as String,
        done: json['done'] as bool,
      );
}
