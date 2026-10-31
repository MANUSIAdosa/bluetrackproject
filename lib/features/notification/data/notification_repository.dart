import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/app_notification.dart';

/// Data source contract for P13 notifications.
///
/// The UI reads the list and the unread count through Riverpod providers
/// (`application/notification_providers.dart`) — never from a widget-level
/// copy of the data, so the list and the badge can never disagree.
abstract interface class NotificationRepository {
  /// Every notification, newest first, with read state included.
  Future<List<AppNotification>> getAll();

  /// Marks one notification as read.
  Future<void> markAsRead(String id);

  /// Marks every notification as read.
  Future<void> markAllAsRead();

  /// Removes one notification.
  Future<void> delete(String id);

  /// Number of unread notifications (badge source).
  Future<int> unreadCount();
}

/// Mock implementation reading `assets/mock/notifications.json`.
///
/// State lives in memory only — marking/deleting survives while the app runs
/// but resets on restart, matching every other mock in this app.
/// TODO(P13, minggu 12-13): replace with notification triggers + persistence
/// (or an API-backed implementation behind this same contract).
class MockNotificationRepository implements NotificationRepository {
  /// Reads the mock asset. Every item's [AppNotification.time] is resolved
  /// against [clock] so tests can pin the reference time.
  MockNotificationRepository();

  /// In-memory seed — used by tests so no asset IO is required.
  MockNotificationRepository.initial(List<AppNotification> items)
      : _items = List.of(items);

  static const _asset = 'assets/mock/notifications.json';

  /// Reference clock. Tests may pin it to make time grouping deterministic.
  DateTime Function() clock = DateTime.now;

  List<AppNotification>? _items;

  Future<List<AppNotification>> _ensureLoaded() async {
    if (_items != null) return _items!;

    final now = clock();
    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = decoded['notifications']! as List<dynamic>;

    _items = [
      for (final row in rows.cast<Map<String, dynamic>>())
        AppNotification.fromJson(row, now),
    ];
    return _items!;
  }

  /// Loads straight from the asset without keeping state — handy for tests
  /// verifying the asset contract itself.
  static Future<List<AppNotification>> loadFromAsset() async {
    final now = DateTime.now();
    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final rows = decoded['notifications']! as List<dynamic>;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        AppNotification.fromJson(row, now),
    ];
  }

  @override
  Future<List<AppNotification>> getAll() => _ensureLoaded().then(
        (items) => [...items]..sort((a, b) => b.time.compareTo(a.time)),
      );

  @override
  Future<void> markAsRead(String id) async {
    final items = _items ?? await _ensureLoaded();
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final item = items[index];
    if (!item.read) {
      items[index] = _withRead(item, true);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    final items = _items ?? await _ensureLoaded();
    for (var i = 0; i < items.length; i++) {
      if (!items[i].read) {
        items[i] = _withRead(items[i], true);
      }
    }
  }

  @override
  Future<void> delete(String id) async {
    final items = _items ?? await _ensureLoaded();
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<int> unreadCount() async {
    final items = _items ?? await _ensureLoaded();
    return items.where((item) => !item.read).length;
  }

  /// `AppNotification` is immutable: a read state change is a new instance, so
  /// equality works for cached Riverpod states.
  AppNotification _withRead(AppNotification item, bool read) => AppNotification(
        id: item.id,
        type: item.type,
        title: item.title,
        body: item.body,
        time: item.time,
        read: read,
        route: item.route,
      );
}
