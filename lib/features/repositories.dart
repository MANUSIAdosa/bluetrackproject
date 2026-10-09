import 'explore/data/project_repository.dart';
import 'notification/data/notification_repository.dart';
import 'organization/data/organization_repository.dart';

/// Repository registry.
///
/// UI imports this single file instead of concrete mock classes, so swapping
/// to API implementations later only changes this file.
abstract final class Repositories {
  static const ProjectRepository projects = MockProjectRepository();
  static const FilterRepository filters = MockFilterRepository();
  static const OrganizationRepository organizations =
      MockOrganizationRepository();
  static const NotificationRepository notifications =
      MockNotificationRepository();
}
