import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'onboarding_widgets.dart';

/// Step 1 — what the app is for, in the words of the design.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingStepLayout(
      icon: Symbols.graphic_eq_rounded,
      headline: l10n.onboardingWelcomeHeadline,
      body: l10n.onboardingWelcomeBody,
    );
  }
}

enum _MicrophoneAccess { unknown, granted, denied }

/// Step 2 — microphone access. The recording plugin owns the platform prompt, so the button
/// only asks it; there is no separate permission package to keep in sync.
class MicrophoneStep extends ConsumerStatefulWidget {
  const MicrophoneStep({super.key});

  @override
  ConsumerState<MicrophoneStep> createState() => _MicrophoneStepState();
}

class _MicrophoneStepState extends ConsumerState<MicrophoneStep> {
  var _access = _MicrophoneAccess.unknown;
  var _asking = false;

  /// Deliberately not called on entering the step: hasPermission() shows the system dialog,
  /// and firing it before the user taps anything is exactly the pattern the design avoids by
  /// drawing an explicit button.
  Future<void> _ask() async {
    setState(() => _asking = true);
    final granted = await ref.read(recorderProvider).hasPermission();
    if (!mounted) return;
    setState(() {
      _asking = false;
      _access = granted ? _MicrophoneAccess.granted : _MicrophoneAccess.denied;
    });
  }

  Widget _trailing(ColorScheme colors, TextTheme text, AppLocalizations l10n) {
    if (_asking) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_access == _MicrophoneAccess.granted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.check_circle_rounded, fill: 1, size: 20, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            l10n.onboardingMicGranted,
            style: text.labelLarge?.copyWith(fontSize: 14, color: colors.primary),
          ),
        ],
      );
    }
    return FilledButton(
      onPressed: _ask,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      child: Text(_access == _MicrophoneAccess.denied
          ? l10n.onboardingMicRetry
          : l10n.onboardingMicAllow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return OnboardingStepLayout(
      icon: Symbols.mic_rounded,
      headline: l10n.onboardingMicHeadline,
      body: l10n.onboardingMicBody,
      children: [
        OnboardingCard(
          icon: Symbols.mic_rounded,
          title: l10n.onboardingMicTitle,
          subtitle: l10n.onboardingMicSubtitle,
          trailing: _trailing(colors, theme.textTheme, l10n),
        ),
        if (_access == _MicrophoneAccess.denied) ...[
          const SizedBox(height: 12),
          Text(
            l10n.onboardingMicDenied,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, color: colors.error),
          ),
        ],
      ],
    );
  }
}

/// Step 3 — the API key. The tile is a link into the existing settings screen; the flow never
/// duplicates that form, and the whole step is skippable by finishing onboarding instead.
class ProviderStep extends StatelessWidget {
  const ProviderStep({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return OnboardingStepLayout(
      icon: Symbols.key_rounded,
      headline: l10n.onboardingProviderHeadline,
      body: l10n.onboardingProviderBody,
      children: [
        OnboardingCard(
          icon: Symbols.key_rounded,
          title: l10n.onboardingProviderTitle,
          subtitle: l10n.onboardingProviderSubtitle,
          highlighted: false,
          onTap: onOpenSettings,
          trailing: Icon(
            Symbols.chevron_right_rounded,
            fill: 1,
            size: 24,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
