import 'package:shared_preferences/shared_preferences.dart';

/// Local registration/reminder state for one action.
class ActionParticipation {
  const ActionParticipation({this.registered = false, this.reminder = false});

  final bool registered;
  final bool reminder;

  ActionParticipation copyWith({bool? registered, bool? reminder}) {
    return ActionParticipation(
      registered: registered ?? this.registered,
      reminder: reminder ?? this.reminder,
    );
  }
}

/// Demo registrations used until the mock backend exposes a signed-in user's
/// joined actions. They keep the Participate Action tab populated on a fresh
/// install; a stored `false` still opts out and a real API can drop them.
const demoJoinedActionIds = <String>{'a03', 'a05'};

/// Persists the signed-in user's participation for the Action Agenda.
///
/// The mock backend has no account state, so the demo keeps the registration
/// and reminder flags on the device. A real API can replace the store without
/// changing the detail page or the joined-action tab.
abstract interface class ActionParticipationStore {
  Future<ActionParticipation> load(String actionId);

  /// Every action id currently marked as registered. Used by the
  /// Participate Action tab.
  Future<Set<String>> registeredIds();

  Future<void> setRegistered(String actionId, bool registered);

  Future<void> setReminder(String actionId, bool enabled);
}

/// `shared_preferences` implementation.
class PrefsActionParticipationStore implements ActionParticipationStore {
  const PrefsActionParticipationStore();

  static const _registeredPrefix = 'action_registered.';
  static const _reminderPrefix = 'action_reminder.';

  @override
  Future<ActionParticipation> load(String actionId) async {
    final prefs = await SharedPreferences.getInstance();
    return ActionParticipation(
      registered:
          prefs.getBool('$_registeredPrefix$actionId') ??
          demoJoinedActionIds.contains(actionId),
      reminder: prefs.getBool('$_reminderPrefix$actionId') ?? false,
    );
  }

  @override
  Future<Set<String>> registeredIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>{...demoJoinedActionIds};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_registeredPrefix)) continue;
      final actionId = key.substring(_registeredPrefix.length);
      if (prefs.getBool(key) ?? false) {
        ids.add(actionId);
      } else {
        ids.remove(actionId);
      }
    }
    return ids;
  }

  @override
  Future<void> setRegistered(String actionId, bool registered) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_registeredPrefix$actionId', registered);
  }

  @override
  Future<void> setReminder(String actionId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_reminderPrefix$actionId', enabled);
  }
}
