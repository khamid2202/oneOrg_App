import 'package:flutter/widgets.dart';

/// Lets a page inside a Home tab take Android's back press before the shell
/// steps back a tab — for a page with its own steps, like Profile's
/// sub-screens or an open teaching tool.
///
/// A `PopScope` can't do this: every `PopScope` on the route hears the same
/// back press, so the page and the shell would both move.
class TabBackScope extends InheritedWidget {
  const TabBackScope({super.key, required this.handlers, required super.child});

  /// Newest last. Each returns true when it used the back press.
  final List<bool Function()> handlers;

  /// Gives the press to the newest handler that wants it.
  static bool dispatch(List<bool Function()> handlers) {
    for (final handle in handlers.reversed.toList()) {
      if (handle()) return true;
    }
    return false;
  }

  static TabBackScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabBackScope>();

  @override
  bool updateShouldNotify(TabBackScope oldWidget) =>
      oldWidget.handlers != handlers;
}

/// Hands back presses to [onBack] while this is on screen. [onBack] returns
/// true when it stepped back inside the page, false to let the shell go back.
class TabBackHandler extends StatefulWidget {
  const TabBackHandler({super.key, required this.onBack, required this.child});

  final bool Function() onBack;
  final Widget child;

  @override
  State<TabBackHandler> createState() => _TabBackHandlerState();
}

class _TabBackHandlerState extends State<TabBackHandler> {
  List<bool Function()>? _handlers;

  bool _handle() => widget.onBack();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handlers = TabBackScope.maybeOf(context)?.handlers;
    if (identical(handlers, _handlers)) return;
    _handlers?.remove(_handle);
    _handlers = handlers?..add(_handle);
  }

  @override
  void dispose() {
    _handlers?.remove(_handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
