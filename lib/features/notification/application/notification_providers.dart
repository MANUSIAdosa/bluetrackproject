import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

/// P13 notification state — Riverpod 3.
///
/// ONE source of truth: the [NotificationListController] re-reads the
/// repository after every mutation, and the badge count is derived from the
/// same list, so the page and the shell/bell badges can never disagree.
/// TODO(P13, minggu 12-13): notification triggers (report status changes,
/// action reminders, location updates) will push into
/// [NotificationListController] from here.

/// Binds the repository once; tests override this provider with an in-memory
/// fake instead of swapping the app registry.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => Repositories.notifications,
);

/// The current notifications, newest first. Loads on first watch and stays
/// alive for the whole session (not autoDispose), so the badge never flickers.
final notificationListProvider =
    AsyncNotifierProvider<NotificationListController, List<AppNotification>>(
  NotificationListController.new,
);

class NotificationListController
    extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() =>
      ref.watch(notificationRepositoryProvider).getAll();

  NotificationRepository get _repo =>
      ref.watch(notificationRepositoryProvider);

  Future<void> markAsRead(String id) =>
      _mutate(() => _repo.markAsRead(id));

  Future<void> markAllAsRead() => _mutate(_repo.markAllAsRead);

  Future<void> delete(String id) => _mutate(() => _repo.delete(id));

  /// Applies the mutation, then re-reads the repository so the local state
  /// always mirrors the actual data source (no optimistic drift).
  Future<void> _mutate(Future<void> Function() action) async {
    await action();
    state = AsyncData(await _repo.getAll());
  }
}

/// Unread count for the shell tab badge and the app-bar bell. Zero while the
/// list is loading or failed, so no badge shows before data exists — matching
/// the P00 part-2 behavior this replaces.
final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationListProvider).value ?? const [];
  return list.where((notification) => !notification.read).length;
});
