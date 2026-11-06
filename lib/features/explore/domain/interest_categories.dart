/// Translates the onboarding interest ids into the project categories they
/// cover.
///
/// The two vocabularies differ on purpose: an interest says what the user
/// wants to support, a category says what a project works on. This is the only
/// place that knows the mapping — the list and the "Untuk minatmu" rail both
/// read it.
abstract final class InterestCategories {
  static const Map<String, List<String>> byInterest = {
    // No mock project covers marine debris yet.
    // TODO(p03): add the marine-debris category to projects.json, then map it.
    'sampah_laut': [],
    'terumbu_karang': ['karang'],
    'mangrove': ['mangrove'],
    'perikanan': ['lamun'],
    'satwa_laut': ['penyu', 'mamalia_laut'],
  };

  /// Categories [interest] matches. Raw category ids (older preferences such
  /// as 'penyu') map to themselves so saved interests keep working.
  static List<String> categoriesOf(String interest) =>
      byInterest[interest] ?? [interest];

  static bool matches(String interest, String projectCategory) =>
      interest == projectCategory ||
      (byInterest[interest]?.contains(projectCategory) ?? false);

  static bool anyMatches(Iterable<String> interests, String projectCategory) =>
      interests.any((interest) => matches(interest, projectCategory));
}
