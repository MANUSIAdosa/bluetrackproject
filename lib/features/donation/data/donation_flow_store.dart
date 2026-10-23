import '../domain/donation.dart';

/// Holds the in-progress donation while the user moves between the amount step,
/// authentication, and the confirmation step.
///
/// In-memory on purpose: the mock flow only has to survive navigation for the
/// current app session. TODO(mock): persist with Hive if the draft must survive
/// an app restart.
class DonationFlowStore {
  DonationFlowStore();

  static final DonationFlowStore instance = DonationFlowStore();

  DonationDraft? _draft;

  DonationDraft? get draft => _draft;

  void save(DonationDraft draft) => _draft = draft;

  void clear() => _draft = null;
}
