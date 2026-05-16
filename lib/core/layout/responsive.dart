import 'package:flutter/widgets.dart';

/// Breakpoints follow Material 3 window-size classes:
///   compact   < 600   (phone portrait)
///   medium    600-839 (phone landscape, small tablet)
///   expanded  840-1199 (tablet portrait, foldable)
///   large     1200+   (tablet landscape, desktop)
enum WindowSize { compact, medium, expanded, large }

class Responsive {
  static const double maxContentWidthCompact = 600;
  static const double maxContentWidthExpanded = 720;

  static WindowSize sizeOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return WindowSize.compact;
    if (w < 840) return WindowSize.medium;
    if (w < 1200) return WindowSize.expanded;
    return WindowSize.large;
  }

  static bool isCompact(BuildContext c) =>
      sizeOf(c) == WindowSize.compact;

  static bool isTabletOrLarger(BuildContext c) {
    final s = sizeOf(c);
    return s == WindowSize.expanded || s == WindowSize.large;
  }

  /// On large screens, constrain content width so 1440px tablets don't look
  /// like stretched phone UIs. Centers the child.
  static EdgeInsets contentInsets(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = sizeOf(context);
    final maxW = size == WindowSize.compact
        ? width
        : (size == WindowSize.medium
            ? maxContentWidthCompact
            : maxContentWidthExpanded);
    final horizontal = ((width - maxW) / 2).clamp(0.0, double.infinity);
    return EdgeInsets.symmetric(horizontal: horizontal);
  }
}

/// Centers + caps width of long-form screens on tablets without affecting
/// full-bleed surfaces like the map / camera. Wrap an entire screen body.
class CappedWidth extends StatelessWidget {
  const CappedWidth({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Caps system text scaling. Some users dial Android accessibility scale to
/// 2.0× and the layouts break. We allow up to 1.3× and let the rest of the
/// accessibility burden fall on contrast + tappable target sizing.
class TextScaleClamp extends StatelessWidget {
  const TextScaleClamp({super.key, required this.child, this.max = 1.3});

  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: max,
        ),
      ),
      child: child,
    );
  }
}
