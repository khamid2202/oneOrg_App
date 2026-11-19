import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Which tour versions each user has seen on this phone, like the web's
/// `product_tours_seen`: `{ userId: version }`. No backend store, so the tour
/// shows once per user per phone.
class ProductTourStore {
  ProductTourStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const storageKey = 'product_tours_seen';

  /// Bump to show the tour again to everyone after a big redesign.
  static const version = 1;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _readAll() async {
    final raw = (await _store).getString(storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// True when storage can't be read, so a broken store never nags.
  Future<bool> hasSeen(Object userId) async {
    try {
      final seen = (await _readAll())['$userId'];
      return seen is num && seen >= version;
    } catch (_) {
      return true;
    }
  }

  Future<void> markSeen(Object userId) async {
    try {
      final all = await _readAll();
      all['$userId'] = version;
      await (await _store).setString(storageKey, jsonEncode(all));
    } catch (_) {
      // Storage blocked: the tour simply shows again next time.
    }
  }
}

/// One stop of the tour. A step without a [target] is a centred card; a step
/// whose target isn't on screen (no such card for this person) is skipped.
class TourStep {
  const TourStep({
    required this.id,
    required this.title,
    required this.body,
    this.target,
  });

  final String id;
  final String title;
  final String body;
  final GlobalKey? target;
}

/// Dims the screen except the current step's target and shows a card beside
/// it with Skip, Back and Next. Brings a target that is scrolled away into
/// view first.
class ProductTour extends StatefulWidget {
  const ProductTour({super.key, required this.steps, required this.onDone});

  final List<TourStep> steps;

  /// Finished or skipped.
  final VoidCallback onDone;

  @override
  State<ProductTour> createState() => _ProductTourState();
}

class _ProductTourState extends State<ProductTour> {
  late final List<TourStep> _steps;
  var _index = 0;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    // Only the steps that have something to point at, decided up front so
    // the "2 of 6" count stays put.
    _steps = [
      for (final step in widget.steps)
        if (step.target == null || step.target!.currentContext != null) step,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus());
  }

  Future<void> _focus() async {
    final target = _steps[_index].target;
    final context = target?.currentContext;
    if (context == null) {
      if (mounted) setState(() => _hole = null);
      return;
    }
    // Steps further down the Home page scroll into view first.
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
      );
    }
    if (!mounted) return;
    setState(() => _hole = _rectOf(target!));
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (box is! RenderBox || me is! RenderBox || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: me);
    return (topLeft & box.size).inflate(6);
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0) return;
    if (next >= _steps.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _index = next;
      _hole = null;
    });
    unawaited(_focus());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final step = _steps[_index];
    final last = _index == _steps.length - 1;
    final hole = step.target == null ? null : _hole;

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        // The card goes below a target in the top half, above one lower down.
        final below = hole != null && hole.center.dy < size.height / 2;
        final card = Material(
          key: const ValueKey('tour-card'),
          color: colors.card,
          elevation: 8,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    step.title,
                    key: ValueKey('tour-step-${step.id}'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(step.body, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      l.tourProgress(_index + 1, _steps.length),
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        key: const ValueKey('tour-skip'),
                        onPressed: widget.onDone,
                        child: Text(
                          l.tourSkip,
                          style: TextStyle(color: colors.mutedText),
                        ),
                      ),
                    if (_index > 0)
                      TextButton(
                        key: const ValueKey('tour-back'),
                        onPressed: () => _go(-1),
                        child: Text(l.back),
                      ),
                    FilledButton(
                      key: const ValueKey('tour-next'),
                      onPressed: () => _go(1),
                      child: Text(last ? l.tourFinish : l.next),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        return Stack(
          children: [
            // Swallows taps so the page underneath stays still.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: CustomPaint(painter: _ScrimPainter(hole)),
              ),
            ),
            if (hole == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: card,
                  ),
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                top: below ? hole.bottom + 12 : null,
                bottom: below ? null : size.height - hole.top + 12,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: card,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);

  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final shape = hole == null
        ? screen
        : Path.combine(
            PathOperation.difference,
            screen,
            Path()..addRRect(
              RRect.fromRectAndRadius(hole!, const Radius.circular(18)),
            ),
          );
    canvas.drawPath(shape, Paint()..color = const Color(0xA6000000));
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(18)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}
