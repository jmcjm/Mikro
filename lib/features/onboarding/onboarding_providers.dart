import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Preference key for the first-run flag. This is the on-disk format: changing its value
/// replays onboarding for every existing user. Two guards spell the literal out instead of
/// going through this constant, so such a change fails the suite — see the tests named
/// STRAZNIK in onboarding_gate_test.dart (read side) and onboarding_screen_test.dart (write
/// side).
const onboardingCompletedKey = 'onboarding_completed';

/// Whether the user has already been through onboarding. False on a fresh install, flipped
/// once the last step is finished and persisted so later launches go straight to the shell.
class OnboardingController extends Notifier<bool> {
  @override
  bool build() {
    // Read untyped: getBool() throws on a value stored under this key with another type
    // (a downgrade, or a key collision), and a crash on the very first frame is a far worse
    // outcome than replaying onboarding.
    return ref.read(sharedPrefsProvider).get(onboardingCompletedKey) == true;
  }

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPrefsProvider).setBool(onboardingCompletedKey, true);
  }
}

final onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);
