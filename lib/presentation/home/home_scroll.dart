import 'package:flutter/material.dart';

/// Home [NestedScrollView] whose floating bar follows the inner list.
///
/// The loading placeholders and the loaded feed must share this view's
/// primary scroll position. A private controller on the feed leaves the
/// header collapsed after the placeholders are replaced.
class HomeNestedScroll extends StatefulWidget {
  const HomeNestedScroll({
    super.key,
    required this.headerSliverBuilder,
    required this.body,
  });

  final NestedScrollViewHeaderSliversBuilder headerSliverBuilder;
  final Widget body;

  /// Brings the title bar back on the frame the real feed replaces the
  /// loading placeholders. No-op outside this widget.
  static void reveal(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_HomeScrollScope>();
    if (scope == null) return;
    scope.reveal(PrimaryScrollController.maybeOf(context));
  }

  @override
  State<HomeNestedScroll> createState() => _HomeNestedScrollState();
}

class _HomeNestedScrollState extends State<HomeNestedScroll> {
  final ScrollController _outer = ScrollController();
  bool _revealed = false;

  @override
  void dispose() {
    _outer.dispose();
    super.dispose();
  }

  void _reveal(ScrollController? primary) {
    if (_revealed) return;
    _revealed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (primary != null && primary.hasClients && primary.offset > 0) {
        primary.jumpTo(0);
      }
      if (_outer.hasClients && _outer.offset > 0) {
        _outer.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScrollScope(
      reveal: _reveal,
      child: NestedScrollView(
        controller: _outer,
        floatHeaderSlivers: true,
        headerSliverBuilder: widget.headerSliverBuilder,
        body: widget.body,
      ),
    );
  }
}

class _HomeScrollScope extends InheritedWidget {
  const _HomeScrollScope({
    required this.reveal,
    required super.child,
  });

  final void Function(ScrollController? primary) reveal;

  @override
  bool updateShouldNotify(_HomeScrollScope oldWidget) => false;
}

/// Paginates a home list on [PrimaryScrollController] when [NestedScrollView]
/// provided one, and on a private controller otherwise.
mixin HomeListScroll<T extends StatefulWidget> on State<T> {
  final ScrollController _ownedScroll = ScrollController();
  ScrollController? _boundScroll;
  bool _ownsBoundScroll = true;
  bool _revealedHomeHeader = false;

  ScrollController get homeScrollController => _boundScroll ?? _ownedScroll;

  void onHomeScroll();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.maybeOf(context);
    final next = primary ?? _ownedScroll;
    if (identical(next, _boundScroll)) return;
    _boundScroll?.removeListener(onHomeScroll);
    _boundScroll = next;
    _ownsBoundScroll = identical(next, _ownedScroll);
    next.addListener(onHomeScroll);
  }

  /// Once, when this list is the real feed rather than the placeholders.
  void revealHomeHeader() {
    if (_revealedHomeHeader) return;
    _revealedHomeHeader = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HomeNestedScroll.reveal(context);
    });
  }

  @override
  void dispose() {
    _boundScroll?.removeListener(onHomeScroll);
    if (_ownsBoundScroll) {
      _ownedScroll.dispose();
    }
    super.dispose();
  }
}
