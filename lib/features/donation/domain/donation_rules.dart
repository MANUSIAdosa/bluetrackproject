/// Fixed donation rules.
///
/// TODO(config): move [minAmount] to `core/config/app_config.dart` once the
/// config owner allows changes outside `features/donation`. It is kept out of
/// widgets on purpose; the confirmation step is the only consumer.
abstract final class DonationRules {
  static const int minAmount = 10000;
}
