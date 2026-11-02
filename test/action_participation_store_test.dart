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
}
