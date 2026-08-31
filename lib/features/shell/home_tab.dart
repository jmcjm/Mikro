import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Breakpoint above which the app switches to the wide layout: navigation moves from bottom to the side rail,
/// and the library expands into a master-detail list and side panel. The design mockup presents this variant
/// at 1280 px without defining a custom breakpoint or media query, so standard MD3 for
/// the "medium" window class (840 dp) is used. A single constant ensures both switches happen at the
/// exact same time: a rail without a side panel (or vice-versa) is an unsupported layout state.
const wideLayoutBreakpoint = 840.0;

/// Shell navigation tabs. Named constants instead of magic numbers, as multiple places
/// outside the shell reference these destinations — empty library state, history button on
/// Record screen, snackbar action, and rail navigation.
abstract final class HomeTab {
  static const recorder = 0;
  static const library = 1;
  static const settings = 2;

  /// Number of destinations. Enforces that [HomeTabController.select] does not accept an index
  /// that IndexedStack cannot render.
  static const count = 3;
}

/// Active shell tab. Lifted from HomeShell's local `setState` because screens inside
/// the IndexedStack also switch tabs — threading callbacks through the widget tree
/// would otherwise be required.
class HomeTabController extends Notifier<int> {
  @override
  int build() => HomeTab.recorder;

  void select(int index) {
    assert(index >= 0 && index < HomeTab.count, 'unknown tab index: $index');
    state = index;
  }
}

final homeTabProvider = NotifierProvider<HomeTabController, int>(HomeTabController.new);
