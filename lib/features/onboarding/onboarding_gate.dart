import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'onboarding_providers.dart';
import 'onboarding_screen.dart';

/// Sends the first launch through onboarding and every later one straight to [child].
///
/// The gate sits inside the route instead of switching `MaterialApp.home`, so finishing
/// onboarding is a plain rebuild of this subtree rather than a route swap.
class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(onboardingCompletedProvider) ? child : const OnboardingScreen();
}
