import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Shared chrome for every onboarding step: the morphing hero, the oversized headline and the
/// supporting line, followed by whatever the step puts under them.
///
/// The layout scrolls because the design is drawn for a 412x892 phone, while the same screen
/// has to survive a short desktop window without spilling a yellow overflow bar over it.
class OnboardingStepLayout extends StatelessWidget {
  const OnboardingStepLayout({
    super.key,
    required this.icon,
    required this.headline,
    required this.body,
    this.children = const [],
  });

  final IconData icon;
  final String headline;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MorphingHero(icon: icon),
          const SizedBox(height: 32),
          Text(
            headline,
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 44,
              height: 48 / 44,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 24 / 16,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 36),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// The blob from the design: a filled square whose corner radii drift between two asymmetric
/// shapes. Mirrors the `morph` keyframes (6 s round trip, ease-in-out) of the mock-up.
class MorphingHero extends StatefulWidget {
  const MorphingHero({super.key, required this.icon, this.size = 96});

  final IconData icon;
  final double size;

  @override
  State<MorphingHero> createState() => _MorphingHeroState();
}

class _MorphingHeroState extends State<MorphingHero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Half of the design's 6 s, because reversing doubles it.
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final Animation<double> _progress =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  /// Percentages straight from the CSS: `border-radius: TL TR BR BL / TL TR BR BL`, horizontal
  /// radii first, so every corner gets an ellipse rather than a circle.
  BorderRadius _radius(List<double> horizontal, List<double> vertical) {
    Radius corner(int i) => Radius.elliptical(
          widget.size * horizontal[i] / 100,
          widget.size * vertical[i] / 100,
        );
    return BorderRadius.only(
      topLeft: corner(0),
      topRight: corner(1),
      bottomRight: corner(2),
      bottomLeft: corner(3),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final from = _radius([44, 56, 52, 48], [50, 44, 56, 50]);
    final to = _radius([56, 44, 46, 54], [44, 56, 44, 56]);
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.lerp(from, to, _progress.value),
        ),
        alignment: Alignment.center,
        child: child,
      ),
      child: Icon(widget.icon, fill: 1, size: widget.size / 2, color: colors.onPrimary),
    );
  }
}

/// One of the two task tiles from the design: round icon badge, two-line label, trailing action.
class OnboardingCard extends StatelessWidget {
  const OnboardingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.highlighted = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Highlighted tiles carry the primary container badge; the muted variant is for a step that
  /// is optional, matching the dimmed API-key tile in the mock-up.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: highlighted ? colors.primaryContainer : colors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  fill: 1,
                  size: 22,
                  color: highlighted ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 13, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Page indicator: the current step stretches into a pill, the rest stay dots.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: i == current ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? colors.primary : colors.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}

/// The bottom-right call to action: label first, arrow second, as drawn.
class OnboardingNextButton extends StatelessWidget {
  const OnboardingNextButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Icon(Symbols.arrow_forward_rounded, fill: 1, size: 20),
        ],
      ),
    );
  }
}
