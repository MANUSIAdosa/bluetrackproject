/// Session-only draft for the action registration wizard.
///
/// The wizard has no backend draft endpoint, so — like the report wizard's
/// draft — the acknowledged step and the equipment statement are kept in memory
/// for the running session. That is what lets a detour to the login page come
/// back to the same step with the same answer instead of restarting the flow.
class ActionRegistrationDraft {
  const ActionRegistrationDraft({
    required this.actionId,
    required this.step,
    required this.equipmentAcked,
  });

  final String actionId;

  /// 1-based wizard step the user was on.
  final int step;

  /// Whether "Saya siap membawanya" was ticked.
  final bool equipmentAcked;
}

abstract interface class ActionRegistrationDraftStore {
  /// The stored draft for [actionId], or null when none belongs to it.
  ActionRegistrationDraft? load(String actionId);

  void save(ActionRegistrationDraft draft);

  /// Forgets the draft — after a successful registration or an explicit exit.
  void clear();
}

/// In-memory implementation. One draft is enough: a user registers for one
/// action at a time.
class InMemoryActionRegistrationDraftStore
    implements ActionRegistrationDraftStore {
  InMemoryActionRegistrationDraftStore();

  static final InMemoryActionRegistrationDraftStore instance =
      InMemoryActionRegistrationDraftStore();

  ActionRegistrationDraft? _draft;

  @override
  ActionRegistrationDraft? load(String actionId) {
    final draft = _draft;
    return draft != null && draft.actionId == actionId ? draft : null;
  }

  @override
  void save(ActionRegistrationDraft draft) => _draft = draft;

  @override
  void clear() => _draft = null;
}
