import '../../../core/config/app_config.dart';

/// Identity used by My Reports and the mock report submitter while auth has no
/// profile. Both features share this single source until auth exposes an id.
const String kMockCurrentUserId = AppConfig.reportCurrentUserId;
