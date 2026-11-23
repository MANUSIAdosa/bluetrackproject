import 'package:blue_track/features/actions/data/action_participation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to not registered without a reminder', () async {
    const store = PrefsActionParticipationStore();

    final state = await store.load('a01');

    expect(state.registered, isFalse);
    expect(state.reminder, isFalse);
  });

  test('persists registration and reminder per action', () async {
    const store = PrefsActionParticipationStore();
    await store.setRegistered('a01', true);
    await store.setReminder('a01', true);

    final reloaded = await const PrefsActionParticipationStore().load('a01');
    expect(reloaded.registered, isTrue);
    expect(reloaded.reminder, isTrue);

    final other = await const PrefsActionParticipationStore().load('a02');
    expect(other.registered, isFalse);
    expect(other.reminder, isFalse);
  });

  test('turns the reminder off without clearing registration', () async {
    const store = PrefsActionParticipationStore();
    await store.setRegistered('a01', true);
    await store.setReminder('a01', true);

    await store.setReminder('a01', false);

    final state = await const PrefsActionParticipationStore().load('a01');
    expect(state.registered, isTrue);
    expect(state.reminder, isFalse);
  });

  test('demo joined actions are registered by default', () async {
    const store = PrefsActionParticipationStore();

    expect((await store.load('a03')).registered, isTrue);
    expect((await store.load('a05')).registered, isTrue);
    expect((await store.load('a01')).registered, isFalse);
  });

  test('registeredIds merges demo actions and stored registrations', () async {
    const store = PrefsActionParticipationStore();
    await store.setRegistered('a01', true);
    await store.setRegistered('a02', false);

    final ids = await store.registeredIds();

    expect(ids, containsAll(['a01', 'a03', 'a05']));
    expect(ids, hasLength(3));
  });

  test('a stored false opt-out removes a demo joined action', () async {
    const store = PrefsActionParticipationStore();
    await store.setRegistered('a03', false);

    final ids = await store.registeredIds();

    expect(ids, isNot(contains('a03')));
    expect((await store.load('a03')).registered, isFalse);
    expect(ids, contains('a05'));
  });
}
