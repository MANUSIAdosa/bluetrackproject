/// Identity used by My Reports while the mock auth has no user profile.
///
/// TODO(auth): replace this with the signed-in user's id once
/// `AuthController` exposes a profile. The mock report data uses `u01`
/// (Ayu Lestari) for its signed-in examples.
const String kMockCurrentUserId = 'u01';
