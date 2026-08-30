import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_screen.dart';
import 'onboarding_providers.dart';
import 'onboarding_steps.dart';
import 'onboarding_widgets.dart';

/// First-run flow: what the app does, microphone access, provider key. The bottom bar lives
/// outside the pager so the call to action stays put while the pages slide under it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 3;

  final _pages = PageController();
  var _step = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step < _stepCount - 1) {
      await _pages.animateToPage(
        _step + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _finish(openSettings: false);
    }
  }

  /// Raising the flag swaps this screen for the shell (see [OnboardingGate]), which unmounts
  /// this widget — hence the navigator is captured before the await, not looked up after it.
  Future<void> _finish({required bool openSettings}) async {
    final navigator = Navigator.of(context);
    await ref.read(onboardingCompletedProvider.notifier).complete();
    if (openSettings) {
      await navigator.push<void>(
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastStep = _step == _stepCount - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // The design is drawn for a phone; on a desktop window the column stays as narrow.
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (page) => setState(() => _step = page),
                    children: [
                      const WelcomeStep(),
                      const MicrophoneStep(),
                      ProviderStep(onOpenSettings: () => _finish(openSettings: true)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: [
                      StepDots(count: _stepCount, current: _step),
                      const Spacer(),
                      OnboardingNextButton(
                        label: isLastStep ? 'Zaczynamy' : 'Dalej',
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
