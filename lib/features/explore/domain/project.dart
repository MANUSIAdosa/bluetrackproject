/// Project domain model (P03/P04).
class Project {
  const Project({
    required this.id,
    required this.title,
    required this.category,
    required this.orgId,
    required this.orgName,
    required this.orgVerified,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.raisedAmount,
    required this.targetAmount,
    required this.description,
    required this.about,
    required this.budget,
    required this.galleryColors,
  });

  final String id;
  final String title;

  /// Category id: penyu | karang | mangrove | mamalia_laut | lamun.
  final String category;
  final String orgId;
  final String orgName;
  final bool orgVerified;
  final String location;
  final double latitude;
  final double longitude;
  final int raisedAmount;
  final int targetAmount;
  final String description;
  final List<String> about;
  final List<BudgetLine> budget;

  /// Hex colors used as gallery placeholders (no image assets in mock data).
  final List<String> galleryColors;

  double get progress =>
      targetAmount == 0 ? 0 : (raisedAmount / targetAmount).clamp(0.0, 1.0);

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        orgId: json['orgId'] as String,
        orgName: json['orgName'] as String,
        orgVerified: json['orgVerified'] as bool? ?? false,
        location: json['location'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        raisedAmount: json['raisedAmount'] as int,
        targetAmount: json['targetAmount'] as int,
        description: json['description'] as String,
        about: (json['about'] as List<dynamic>).cast<String>(),
        budget: (json['budget'] as List<dynamic>)
            .map((e) => BudgetLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        galleryColors:
            (json['galleryColors'] as List<dynamic>).cast<String>(),
      );
}

class BudgetLine {
  const BudgetLine({
    required this.item,
    required this.amount,
    required this.percent,
  });

  final String item;
  final int amount;

  /// Share of total, 0–100.
  final int percent;

  factory BudgetLine.fromJson(Map<String, dynamic> json) => BudgetLine(
        item: json['item'] as String,
        amount: json['amount'] as int,
        percent: json['percent'] as int,
      );
}
