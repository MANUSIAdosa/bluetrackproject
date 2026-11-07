import 'package:blue_track/features/actions/data/action_repository.dart';
import 'package:blue_track/features/actions/domain/action_item.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/action_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockActionRepository detail', () {
    test('returns an action with description, meeting point, equipment and '
        'organizer id', () async {
      final item = await const MockActionRepository(
        delay: Duration.zero,
      ).getActionById('a02');

      expect(item, isNotNull);
      expect(item!.id, 'a02');
      expect(item.description, isNotEmpty);
      expect(item.meetingPoint, isNotEmpty);
      expect(item.equipment, isNotEmpty);
      expect(item.organizerId, 'o01');
      expect(item.type, ActionType.coralRestoration);
    });

    test('returns null for an unknown action', () async {
      final item = await const MockActionRepository(
        delay: Duration.zero,
      ).getActionById('missing');

      expect(item, isNull);
    });

    test('simulates a successful registration', () async {
      await expectLater(
        const MockActionRepository(
          delay: Duration.zero,
        ).registerAction('a01'),
        completes,
      );
    });

    test('can simulate a registration failure', () async {
      const repository = MockActionRepository(
        delay: Duration.zero,
        simulateRegistrationFailure: true,
      );

      await expectLater(
        repository.registerAction('a01'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ActionItem status', () {
    test('is open before the start, full at quota, and ended after the end', () {
      final now = DateTime(2026, 11, 3, 9);
      final open = buildAction(
        startsAt: DateTime(2026, 11, 8, 7),
        endsAt: DateTime(2026, 11, 8, 10),
      );
      final full = buildAction(quota: 40, registered: 40);
      final ended = buildAction(
        startsAt: DateTime(2026, 11, 1, 7),
        endsAt: DateTime(2026, 11, 1, 10),
      );

      expect(open.statusAt(now), ActionStatus.open);
      expect(open.canRegisterAt(now), isTrue);
      expect(full.statusAt(now), ActionStatus.full);
      expect(full.canRegisterAt(now), isFalse);
      expect(ended.statusAt(now), ActionStatus.ended);
      expect(ended.canRegisterAt(now), isFalse);
    });

    test('registration closes exactly when the action starts', () {
      final item = buildAction(
        startsAt: DateTime(2026, 11, 8, 7),
        endsAt: DateTime(2026, 11, 8, 10),
      );

      expect(item.canRegisterAt(DateTime(2026, 11, 8, 6, 59)), isTrue);
      expect(item.canRegisterAt(DateTime(2026, 11, 8, 7)), isFalse);
    });
  });
}
