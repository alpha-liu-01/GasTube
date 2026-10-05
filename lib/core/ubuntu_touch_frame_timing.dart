import 'dart:io';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:fluxtube/core/ubuntu_touch.dart';

/// Release frame timings for the Ubuntu Touch package.
///
/// The engine reports these about once a second. [FrameTiming.rasterDuration]
/// ends when the compositor framebuffer is ready. The later
/// `gdk_cairo_draw_from_gl` copy is logged separately by the runner as
/// `present: blit`.
void installUbuntuTouchFrameTiming() {
  if (!UbuntuTouch.enabled) return;
  SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
}

void _onFrameTimings(List<FrameTiming> timings) {
  if (timings.isEmpty) return;
  final build = _Stats();
  final raster = _Stats();
  final span = _Stats();
  final wait = _Stats();
  final queue = _Stats();
  for (final timing in timings) {
    build.add(timing.buildDuration);
    raster.add(timing.rasterDuration);
    span.add(timing.totalSpan);
    wait.add(timing.vsyncOverhead);
    final queueUs = timing.timestampInMicroseconds(FramePhase.rasterStart) -
        timing.timestampInMicroseconds(FramePhase.buildFinish);
    queue.add(Duration(microseconds: queueUs < 0 ? 0 : queueUs));
  }
  stderr.writeln(
    'gastube: frame n=${timings.length} '
    'build_avg=${build.avgMs} build_max=${build.maxMs} '
    'build_over16=${build.overBudget} '
    'raster_avg=${raster.avgMs} raster_max=${raster.maxMs} '
    'raster_over16=${raster.overBudget} '
    'wait_avg=${wait.avgMs} wait_max=${wait.maxMs} '
    'queue_avg=${queue.avgMs} queue_max=${queue.maxMs} '
    'span_avg=${span.avgMs} span_max=${span.maxMs} '
    'span_over16=${span.overBudget}',
  );
}

class _Stats {
  static const double _budgetUs = 16700;

  int _count = 0;
  int _sumUs = 0;
  int _maxUs = 0;
  int overBudget = 0;

  void add(Duration duration) {
    final us = duration.inMicroseconds;
    _count++;
    _sumUs += us;
    if (us > _maxUs) _maxUs = us;
    if (us > _budgetUs) overBudget++;
  }

  String get avgMs {
    if (_count == 0) return '0.00';
    return (_sumUs / _count / 1000).toStringAsFixed(2);
  }

  String get maxMs => (_maxUs / 1000).toStringAsFixed(2);
}
