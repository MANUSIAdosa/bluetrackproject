import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Data source contract for the unread notification count (P13).
///
/// TODO(P13): widen to `Future<List<Notification>> getNotifications()` once
/// the real list exists. Until then only the count is exposed, so no
/// notification type or list UI is implied by this contract.
abstract interface class NotificationRepository {
  /// Number of unread items. At this stage notifications mean news about the
  /// user's donations, but the count itself is type-agnostic.
  Future<int> getUnreadCount();
}

/// Mock implementation reading `assets/mock/notifications.json`.
class MockNotificationRepository implements NotificationRepository {
  const MockNotificationRepository();

  static const _asset = 'assets/mock/notifications.json';

  @override
  Future<int> getUnreadCount() async {
    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded['unreadCount'] as int? ?? 0;
  }
}