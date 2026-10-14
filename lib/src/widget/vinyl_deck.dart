import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

const vinylCream = Color(0xFFF1EFE7);
const vinylInk = Color(0xFF262923);
const vinylOlive = Color(0xFF657052);
const vinylGold = Color(0xFFDBBE7E);
const vinylRevolution = Duration(seconds: 60);
const vinylArmGrabDelay = Duration(milliseconds: 260);

String vinylTime(Duration time) =>
    '${time.inMinutes}:${(time.inSeconds % 60).toString().padLeft(2, '0')}';

enum VinylInteraction { scrub, skip }

class VinylTrackPreview {
  const VinylTrackPreview({required this.title, required this.cover});
  final String title;
  final Widget cover;
}

/// Shared dimensions keep the record, needle drawing and touch targets aligned.
class VinylDeckGeometry {
  const VinylDeckGeometry(this.size);
  static const aspectRatio = .88;
  final Size size;

  Rect get record => Rect.fromLTWH(
      size.width * .04, size.width * .045, size.width * .92, size.width * .92);
  Offset get pivot => Offset(size.width * .115, size.height * .905);
  double get armLength => size.width * .75;
  Offset get parkedTip => pivot + Offset(armLength, 0);

  double _playingAngle(double progress) {
    final toCenter = record.center - pivot;
    final radius = record.width / 2 * (.96 - progress.clamp(0, 1) * .54);
    final cosine =
        (armLength * armLength + toCenter.distanceSquared - radius * radius) /
            (2 * armLength * toCenter.distance);
    return math.atan2(toCenter.dy, toCenter.dx) +
        math.acos(cosine.clamp(-1, 1));
  }

  Offset tip(double lowered, double progress) {
    final angle = _playingAngle(progress) * lowered.clamp(0, 1);
    return pivot + Offset(math.cos(angle), math.sin(angle)) * armLength;
  }

  Offset needleTip(double lowered, double progress, {bool lifted = false}) =>
      tip(lowered, progress) + Offset(0, lifted ? -5 : 0);

  bool isNeedleOnRecord(double lowered, double progress,
      {bool lifted = false}) {
    final offset = needleTip(lowered, progress, lifted: lifted) - record.center;
    final radius = record.width / 2;
    return offset.distanceSquared <= radius * radius;
  }

  Offset elbow(Offset tip) {
    final vector = tip - pivot;
    final normal = Offset(-vector.dy, vector.dx) / vector.distance;
    return Offset.lerp(pivot, tip, .78)! + normal * size.width * .03;
  }

  double loweredAt(Offset position, double progress) {
    final vector = position - pivot;
    return (math.atan2(vector.dy, vector.dx) / _playingAngle(progress))
        .clamp(0.0, 1.0);
  }
}

/// Outer grooves scrub; the center switches tracks and opens the shelf or saves.
class VinylDeck extends StatefulWidget {
  const VinylDeck(
      {super.key,
      required this.playing,
      required this.position,
      required this.duration,
      required this.cover,
      this.enabled = true,
      this.busy = false,
      this.unavailableDirection,
      this.previousTrack,
      this.nextTrack,
      this.canSkipPrevious = true,
      this.canSkipNext = true,
      this.onLabelLongPress,
      this.onLabelSwipeUp,
      this.onLabelSwipeDown,
      this.onScrubStart,
      this.onScrubCancel,
      this.onInteraction,
      required this.onArmChanged,
      required this.onSeek,
      required this.onSkip,
      this.onScrubChanged});
  final VoidCallback? onLabelLongPress;
  final VoidCallback? onLabelSwipeUp;
  final VoidCallback? onLabelSwipeDown;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubCancel;
  final ValueChanged<VinylInteraction>? onInteraction;
  final bool playing;
  final bool enabled;
  final bool busy;
  final int? unavailableDirection;
  final VinylTrackPreview? previousTrack;
  final VinylTrackPreview? nextTrack;
  final bool canSkipPrevious;
  final bool canSkipNext;
  final Duration position;
  final Duration duration;
  final Widget cover;
  final Future<void> Function(bool) onArmChanged;
  final Future<void> Function(Duration) onSeek;
  final Future<void> Function(int) onSkip;
  final ValueChanged<Duration?>? onScrubChanged;

  @override
  State<VinylDeck> createState() => _VinylDeckState();
}

class _VinylDeckState extends State<VinylDeck> with TickerProviderStateMixin {
  late final _translation = AnimationController.unbounded(vsync: this);
  late final _pull = AnimationController.unbounded(vsync: this);
  late final _press = AnimationController(vsync: this);
  double _dragOrigin = 0;
  double _pullOrigin = 0;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _clearArm();
    _translation.dispose();
    _pull.dispose();
    _press.dispose();
    super.dispose();
  }

  int? _recordPointer;
  Timer? _longPressTimer;
  Offset? _pressOrigin;
  bool _longPressed = false;
  double _sweep = 0;
  double _lastAngle = 0;
  Offset? _start;
  Offset? _end;
  bool _swiping = false;
  bool _notifiedSkip = false;
  Duration? _target;
  Duration? _pendingSeek;
  Duration _scrubOrigin = Duration.zero;
  double? _armDrag;
  bool _armHeld = false;
  bool? _armSnap;
  int? _armPointer;
  Offset? _armPressOrigin;
  Offset? _armLastPosition;
  Timer? _armGrabTimer;
  bool _armMoved = false;
  final _skipThresholdDirections = <int>{};

  Offset get _labelMovement =>
      _start == null || _end == null ? Offset.zero : _end! - _start!;

  int? _skipDirection(Offset movement, {double threshold = 12}) => _swiping &&
          movement.dx.abs() >= threshold &&
          movement.dy.abs() < movement.dx.abs() * .65
      ? (movement.dx < 0 ? 1 : -1)
      : null;

  bool _canSkip(int direction) =>
      direction < 0 ? widget.canSkipPrevious : widget.canSkipNext;

  void _clearArm() {
    _armGrabTimer?.cancel();
    _armGrabTimer = null;
    _armHeld = false;
    _armDrag = null;
    _armSnap = null;
    _armPointer = null;
    _armPressOrigin = null;
    _armLastPosition = null;
    _armMoved = false;
  }

  void _releaseArm() => setState(_clearArm);

  void _startArm(PointerDownEvent event, VinylDeckGeometry geometry) {
    if (!_available || _armPointer != null || _start != null) return;
    // Own the pointer immediately, but keep tap feedback visually steady.
    _armPointer = event.pointer;
    _armPressOrigin = event.localPosition;
    _armLastPosition = event.localPosition;
    _armMoved = false;
    _armGrabTimer = Timer(vinylArmGrabDelay, () {
      if (!mounted || !_available || _armPointer != event.pointer) return;
      setState(() {
        _armHeld = true;
        _armDrag = widget.playing ? 1 : 0;
        _armSnap = null;
      });
      if (_armMoved) {
        final progress = widget.duration > Duration.zero
            ? (widget.position.inMilliseconds / widget.duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;
        _dragArm(_armLastPosition!, geometry, progress);
      }
    });
  }

  void _moveArm(
      PointerMoveEvent event, VinylDeckGeometry geometry, double progress) {
    if (event.pointer != _armPointer || !_available) return;
    _armLastPosition = event.localPosition;
    final distance = (event.localPosition - _armPressOrigin!).distance;
    if (distance >
        computeHitSlop(event.kind, MediaQuery.gestureSettingsOf(context))) {
      _armMoved = true;
    }
    if (_armHeld && _armMoved) {
      _dragArm(event.localPosition, geometry, progress);
    }
  }

  void _endArm(PointerUpEvent event) {
    if (event.pointer != _armPointer) return;
    final moved = _armMoved;
    final grabbed = _armHeld;
    final lowered = _armSnap;
    _releaseArm();
    if (!_available) return;
    if (!grabbed && !moved) {
      HapticFeedback.lightImpact();
      widget.onArmChanged(!widget.playing);
    } else if (grabbed &&
        moved &&
        lowered != null &&
        lowered != widget.playing) {
      HapticFeedback.lightImpact();
      widget.onArmChanged(lowered);
    }
  }

  void _dragArm(Offset position, VinylDeckGeometry geometry, double progress) {
    final lowered = geometry.loweredAt(position, progress);
    // Use the visible needle and the circular record, rather than an angle target.
    final snap = geometry.isNeedleOnRecord(lowered, progress, lifted: true)
        ? true
        : _armSnap == false && lowered <= .24
            ? false
            : lowered <= .16
                ? false
                : null;
    if (snap != null && snap != _armSnap) HapticFeedback.selectionClick();
    setState(() {
      _armSnap = snap;
      _armDrag = snap == null ? lowered : (snap ? 1 : 0);
    });
  }

  @override
  void didUpdateWidget(VinylDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_available) _clearArm();
    if (!widget.busy &&
        (oldWidget.busy || widget.position != oldWidget.position)) {
      _pendingSeek = null;
    }
  }

  bool get _available => widget.enabled && !widget.busy;
  Duration _scrubTarget() {
    final milliseconds = _scrubOrigin.inMilliseconds +
        _sweep / (2 * math.pi) * vinylRevolution.inMilliseconds;
    return Duration(
        milliseconds:
            milliseconds.round().clamp(0, widget.duration.inMilliseconds));
  }

  void _startRecord(Offset position, double diameter) {
    if (widget.busy) return;
    final center = Offset(diameter / 2, diameter / 2);
    final local = position - center;
    _swiping = local.distance < diameter * .29;
    if (!_available && !(_swiping && widget.onLabelSwipeUp != null)) return;
    _translation.stop();
    _pull.stop();
    _dragOrigin = _translation.value;
    _pullOrigin = _pull.value;
    _start = position;
    _end = _start;
    _skipThresholdDirections.clear();
    _sweep = 0;
    _scrubOrigin = widget.position;
    _lastAngle = math.atan2(local.dy, local.dx);
    _notifiedSkip = false;
    if (!_swiping && _available && widget.duration > Duration.zero) {
      setState(() => _target = _scrubOrigin);
      widget.onScrubStart?.call();
      widget.onScrubChanged?.call(_target);
      widget.onInteraction?.call(VinylInteraction.scrub);
    }
  }

  void _moveRecord(Offset position, double diameter) {
    if (_start == null || widget.busy) return;
    _end = position;
    if (_swiping) {
      final movement = _end! - _start!;
      if (!_notifiedSkip && _skipDirection(movement) != null && _available) {
        _notifiedSkip = true;
        widget.onInteraction?.call(VinylInteraction.skip);
      }
      final direction = _skipDirection(movement, threshold: 48);
      if (direction != null &&
          _available &&
          _canSkip(direction) &&
          _skipThresholdDirections.add(direction)) {
        HapticFeedback.selectionClick();
      }
      final displacement = _dragOrigin + movement.dx * .18;
      _translation.value = 24 * displacement / (24 + displacement.abs());
      final pullingVertically =
          ((movement.dy > 0 && widget.onLabelSwipeDown != null) ||
                  (movement.dy < 0 && widget.onLabelSwipeUp != null)) &&
              movement.dy.abs() > movement.dx.abs() &&
              !MediaQuery.of(context).disableAnimations;
      final pull = _pullOrigin + movement.dy * .35;
      _pull.value = pullingVertically ? 42 * pull / (42 + pull.abs()) : 0;
      setState(() {});
      return;
    }
    if (!_available || widget.duration <= Duration.zero) return;
    final local = position - Offset(diameter / 2, diameter / 2);
    if (local.distance < diameter * .18) return;
    final angle = math.atan2(local.dy, local.dx);
    var delta = angle - _lastAngle;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _lastAngle = angle;
    _sweep += delta;
    setState(() {
      _target = _scrubTarget();
    });
    widget.onScrubChanged?.call(_target);
  }

  Future<void> _endRecord() async {
    final movement = _labelMovement;
    final target = _target;
    final skipDirection = _skipDirection(movement, threshold: 48);
    final swipe = skipDirection != null;
    final swipeDown =
        _swiping && movement.dy >= 48 && movement.dx.abs() < movement.dy * .65;
    final swipeUp = _swiping &&
        movement.dy <= -48 &&
        movement.dx.abs() < -movement.dy * .65;
    if (target != null && !swipe) _pendingSeek = target;
    _cancelRecord();
    if (widget.busy) return;
    if (swipeUp && widget.onLabelSwipeUp != null) {
      HapticFeedback.selectionClick();
      widget.onLabelSwipeUp!();
      return;
    }
    if (!_available) return;
    if (swipeDown && widget.onLabelSwipeDown != null) {
      HapticFeedback.selectionClick();
      widget.onLabelSwipeDown!();
    } else if (swipe) {
      await widget.onSkip(skipDirection);
    } else if (target != null) {
      HapticFeedback.selectionClick();
      await widget.onSeek(target);
    }
  }

  void _cancelRecord({bool cancelled = false}) {
    final hadScrub = _target != null && !_swiping;
    if (MediaQuery.of(context).disableAnimations) {
      _translation.value = 0;
      _pull.value = 0;
      _press.value = 0;
    } else {
      _translation.animateTo(0,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic);
      _pull.animateTo(0,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
      _releasePress();
    }
    setState(() {
      _start = null;
      _end = null;
      _target = null;
    });
    widget.onScrubChanged?.call(null);
    if (cancelled && hadScrub) widget.onScrubCancel?.call();
  }

  void _releasePress() {
    if (MediaQuery.of(context).disableAnimations) {
      _press.value = 0;
    } else {
      _press.animateTo(0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final geometry = VinylDeckGeometry(
            Size(width, width / VinylDeckGeometry.aspectRatio));
        final record = geometry.record;
        final diameter = record.width;
        final progress = widget.duration > Duration.zero
            ? ((_target ?? _pendingSeek ?? widget.position).inMilliseconds /
                    widget.duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;
        final arm = _armDrag ?? (widget.playing ? 1.0 : 0.0);
        final previewDirection =
            _available ? _skipDirection(_labelMovement) : null;
        final skipReady = _skipDirection(_labelMovement, threshold: 48) != null;
        return AspectRatio(
            aspectRatio: VinylDeckGeometry.aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF85705C), Color(0xFF5C4C3D)]),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF3A3228).withOpacity(.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12))
                  ]),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(children: [
                    Positioned.fill(
                        child: CustomPaint(painter: _PlinthPainter())),
                    Positioned(
                      left: record.left,
                      top: record.top,
                      width: diameter,
                      height: diameter,
                      child: Semantics(
                          label:
                              '唱片，外圈旋转调整播放位置，中心左右拨动换曲，中心上滑打开播放列表，中心下滑收藏到歌单，长按中心打开歌单',
                          onLongPress:
                              widget.busy ? null : widget.onLabelLongPress,
                          value: '${(_target ?? widget.position).inSeconds} 秒',
                          increasedValue:
                              '${(widget.position.inSeconds + 10).clamp(0, widget.duration.inSeconds)} 秒',
                          decreasedValue:
                              '${(widget.position.inSeconds - 10).clamp(0, widget.duration.inSeconds)} 秒',
                          onIncrease: _available && widget.duration > Duration.zero
                              ? () => widget.onSeek(Duration(
                                  milliseconds:
                                      (widget.position.inMilliseconds + 10000)
                                          .clamp(0,
                                              widget.duration.inMilliseconds)))
                              : null,
                          onDecrease: _available && widget.duration > Duration.zero
                              ? () => widget.onSeek(Duration(
                                  milliseconds: (widget.position.inMilliseconds -
                                          10000)
                                      .clamp(0, widget.duration.inMilliseconds)))
                              : null,
                          child: RawGestureDetector(
                              // Own the gesture from pointer-down, before the
                              // enclosing page's vertical scroll recognizer.
                              gestures: (_available || (!widget.busy && (widget.onLabelLongPress != null || widget.onLabelSwipeUp != null)))
                                  ? {
                                      EagerGestureRecognizer:
                                          GestureRecognizerFactoryWithHandlers<
                                              EagerGestureRecognizer>(
                                        EagerGestureRecognizer.new,
                                        (_) {},
                                      ),
                                    }
                                  : const {},
                              child: Listener(
                                key: const ValueKey('vinyl-record'),
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (event) {
                                  if (widget.busy || _recordPointer != null) {
                                    return;
                                  }
                                  _recordPointer = event.pointer;
                                  _pressOrigin = event.localPosition;
                                  _longPressed = false;
                                  _startRecord(event.localPosition, diameter);
                                  final distance = (event.localPosition -
                                          Offset(diameter / 2, diameter / 2))
                                      .distance;
                                  if (distance <= diameter * .175 &&
                                      widget.onLabelLongPress != null) {
                                    if (!MediaQuery.of(context)
                                        .disableAnimations) {
                                      _press.animateTo(1,
                                          duration: kLongPressTimeout,
                                          curve: Curves.easeInOutCubic);
                                    }
                                    _longPressTimer =
                                        Timer(kLongPressTimeout, () {
                                      if (!mounted ||
                                          _recordPointer == null ||
                                          widget.busy) return;
                                      _longPressed = true;
                                      _cancelRecord();
                                      HapticFeedback.selectionClick();
                                      widget.onLabelLongPress?.call();
                                    });
                                  }
                                },
                                onPointerMove: (event) {
                                  if (event.pointer != _recordPointer ||
                                      _longPressed) return;
                                  if (_pressOrigin != null &&
                                      (event.localPosition - _pressOrigin!)
                                              .distance >
                                          kTouchSlop) {
                                    _longPressTimer?.cancel();
                                    _releasePress();
                                  }
                                  _moveRecord(event.localPosition, diameter);
                                },
                                onPointerUp: (event) {
                                  if (event.pointer != _recordPointer) return;
                                  _longPressTimer?.cancel();
                                  _releasePress();
                                  _recordPointer = null;
                                  _pressOrigin = null;
                                  if (!_longPressed) _endRecord();
                                },
                                onPointerCancel: (event) {
                                  if (event.pointer != _recordPointer) return;
                                  _longPressTimer?.cancel();
                                  _recordPointer = null;
                                  _pressOrigin = null;
                                  _cancelRecord(cancelled: true);
                                },
                                child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _translation,
                                      _pull,
                                      _press,
                                    ]),
                                    builder: (context, child) =>
                                        Transform.translate(
                                            offset: Offset(_translation.value,
                                                _pull.value),
                                            child: Transform.scale(
                                                scale: 1 -
                                                    _press.value * .045 -
                                                    (_pull.value.abs() / 42) *
                                                        .025,
                                                child: child)),
                                    child: VinylRecord(
                                        playing: widget.playing &&
                                            !widget.busy &&
                                            _start == null &&
                                            _pendingSeek == null,
                                        position: _target ??
                                            _pendingSeek ??
                                            widget.position,
                                        cover: widget.cover)),
                              ))),
                    ),
                    if (previewDirection != null)
                      Positioned(
                        left: previewDirection < 0 ? 12 : null,
                        right: previewDirection > 0 ? 12 : null,
                        top: record.top + diameter * .15,
                        width: diameter * .4,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity:
                                (_labelMovement.dx.abs() / 48).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: MediaQuery.disableAnimationsOf(context)
                                  ? Offset.zero
                                  : Offset(
                                      previewDirection *
                                          24 *
                                          (1 -
                                              (_labelMovement.dx.abs() / 48)
                                                  .clamp(0.0, 1.0)),
                                      0),
                              child: _SkipPreview(
                                key: const ValueKey('vinyl-skip-preview'),
                                direction: previewDirection,
                                track: previewDirection < 0
                                    ? widget.previousTrack
                                    : widget.nextTrack,
                                available: _canSkip(previewDirection),
                                ready: skipReady,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned.fill(
                        key: const ValueKey('tonearm-surface'),
                        child: TweenAnimationBuilder<double>(
                            tween: Tween(end: arm),
                            duration: _armHeld ||
                                    MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeInOutCubic,
                            builder: (context, value, _) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Semantics(
                                        label: widget.playing
                                            ? '抬起唱针，暂停'
                                            : '放下唱针，播放',
                                        button: true,
                                        onTap: _available
                                            ? () => widget
                                                .onArmChanged(!widget.playing)
                                            : null,
                                        child: RawGestureDetector(
                                          key: const ValueKey('tonearm'),
                                          // Reserve the pointer on down, before the page's
                                          // horizontal/vertical recognizers reach their slop.
                                          // Defer to the painter so blank deck areas stay free.
                                          behavior:
                                              HitTestBehavior.deferToChild,
                                          gestures: {
                                            EagerGestureRecognizer:
                                                GestureRecognizerFactoryWithHandlers<
                                                        EagerGestureRecognizer>(
                                                    EagerGestureRecognizer.new,
                                                    (_) {}),
                                          },
                                          child: Listener(
                                            behavior:
                                                HitTestBehavior.deferToChild,
                                            onPointerDown: (event) =>
                                                _startArm(event, geometry),
                                            onPointerMove: (event) => _moveArm(
                                                event, geometry, progress),
                                            onPointerUp: _endArm,
                                            onPointerCancel: (event) {
                                              if (event.pointer ==
                                                  _armPointer) {
                                                _releaseArm();
                                              }
                                            },
                                            child: CustomPaint(
                                                painter: _TonearmPainter(
                                                    value, progress,
                                                    lifted: _armHeld)),
                                          ),
                                        )),
                                    if (_target != null ||
                                        (widget.enabled &&
                                            widget.duration > Duration.zero))
                                      Positioned.fill(
                                          child: IgnorePointer(
                                              child: CustomMultiChildLayout(
                                                  delegate: _TimeBubbleLayout(
                                                      geometry,
                                                      geometry.tip(
                                                          value, progress)),
                                                  children: [
                                            if (widget.enabled &&
                                                widget.duration > Duration.zero)
                                              LayoutId(
                                                  id: _TimeBubbleSlot.duration,
                                                  child: _GlassTimeBubble(
                                                      key: const ValueKey(
                                                          'vinyl-total-time'),
                                                      time: widget.duration)),
                                            if (_target != null)
                                              LayoutId(
                                                  id: _TimeBubbleSlot.position,
                                                  child: _GlassTimeBubble(
                                                      key: const ValueKey(
                                                          'vinyl-scrub-time'),
                                                      time: _target!,
                                                      delta: _target! -
                                                          _scrubOrigin)),
                                          ]))),
                                  ],
                                ))),
                    if (_armHeld)
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 14,
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: _DeckHint(
                              key: const ValueKey('tonearm-grab-hint'),
                              text: _armSnap == true
                                  ? '松手落针播放'
                                  : _armSnap == false
                                      ? '松手归位暂停'
                                      : '已拿起唱针 · 移到唱片或支架',
                            ),
                          ),
                        ),
                      ),
                    for (final direction in [-1, 1])
                      Positioned(
                        left: record.left + (direction > 0 ? diameter / 2 : 0),
                        top: record.top,
                        width: diameter / 2,
                        height: diameter,
                        child: IgnorePointer(
                            child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: widget.unavailableDirection != direction
                              ? const SizedBox.shrink()
                              : Semantics(
                                  label: direction < 0 ? '没有上一曲' : '没有下一曲',
                                  liveRegion: true,
                                  child: SizedBox.expand(
                                    key: ValueKey(direction < 0
                                        ? 'no-previous-track'
                                        : 'no-next-track'),
                                    child: CustomPaint(
                                        painter: _RecordEdgePainter(direction)),
                                  ),
                                ),
                        )),
                      ),
                    Positioned(
                        left: width * .26,
                        bottom: 14,
                        child: Row(children: [
                          AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.playing
                                      ? const Color(0xFFD7E6AC)
                                      : const Color(0xFFAD9D86),
                                  boxShadow: widget.playing
                                      ? [
                                          const BoxShadow(
                                              color: Color(0x88D7E6AC),
                                              blurRadius: 8)
                                        ]
                                      : [])),
                          const SizedBox(width: 8),
                          Text(
                              widget.busy
                                  ? 'LOADING'
                                  : widget.playing
                                      ? 'PLAYING'
                                      : 'STANDBY',
                              style: const TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 1.5,
                                  color: Color(0xFFE9DECB))),
                        ])),
                    Positioned(
                        right: 16,
                        bottom: 12,
                        child: Text('L2 / 01',
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1,
                                color: Colors.white.withOpacity(.45)))),
                  ])),
            ));
      });
}

class _DeckHint extends StatelessWidget {
  const _DeckHint({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xEB262923),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: vinylGold.withOpacity(.4)),
        ),
        child: Text(text,
            style:
                const TextStyle(color: vinylCream, fontSize: 11, height: 1.4)),
      );
}

class _SkipPreview extends StatelessWidget {
  const _SkipPreview({
    super.key,
    required this.direction,
    required this.track,
    required this.available,
    required this.ready,
  });
  final int direction;
  final VinylTrackPreview? track;
  final bool available;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final hint = !available
        ? (direction < 0 ? '第一张了' : '最后一张了')
        : ready
            ? '松手换${direction < 0 ? '上一张' : '下一张'}'
            : '继续拨动换曲';
    return Semantics(
      liveRegion: true,
      label: '$hint${available && track != null ? '，${track!.title}' : ''}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: vinylCream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: ready && available ? vinylGold : const Color(0xFFB6A58A),
                width: ready && available ? 2 : 1),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 5)),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (available) ...[
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: track?.cover ??
                      const ColoredBox(
                        color: Color(0xFFE5D8B6),
                        child: Center(
                            child:
                                Icon(Icons.album_outlined, color: vinylOlive)),
                      ),
                ),
              ),
              const SizedBox(height: 7),
              Text(track?.title ?? '唱片信息加载中…',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: vinylInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
            ],
            Text(hint,
                style: const TextStyle(
                    color: vinylOlive, fontSize: 10, height: 1.4)),
          ]),
        ),
      ),
    );
  }
}

class _GlassTimeBubble extends StatelessWidget {
  const _GlassTimeBubble({super.key, required this.time, this.delta});
  final Duration time;
  final Duration? delta;

  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(100)),
          boxShadow: [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4))
          ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: ColoredBox(
                  color: const Color(0x40201E1A),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0x4DFFFFFF),
                                Color(0x14322E28),
                                Color(0x33FFFFFF)
                              ],
                              stops: [
                                0,
                                .55,
                                1
                              ]),
                          border: Border.all(
                              color: const Color(0x99FFFFFF), width: .8)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            delta == null
                                ? vinylTime(time)
                                : '目标 ${vinylTime(time)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: vinylCream,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ],
                                shadows: [
                                  Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 2,
                                      offset: Offset(0, 1))
                                ])),
                        if (delta != null) ...[
                          const SizedBox(height: 3),
                          Text(
                              '${delta!.inMilliseconds < 0 ? '−' : '+'}${delta!.inSeconds.abs()} 秒',
                              style: const TextStyle(
                                  color: vinylCream, fontSize: 10)),
                        ],
                      ]))))));
}

enum _TimeBubbleSlot { duration, position }

class _TimeBubbleLayout extends MultiChildLayoutDelegate {
  _TimeBubbleLayout(this.geometry, this.needle);
  final VinylDeckGeometry geometry;
  final Offset needle;
  static const _margin = 12.0;

  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(Size(
        math.max(0, size.width - _margin * 2),
        math.max(0, size.height - _margin * 2)));
    double fitX(double x, Size bubble) => x.clamp(
        _margin, math.max(_margin, size.width - bubble.width - _margin));
    double fitY(double y, Size bubble) => y.clamp(
        _margin, math.max(_margin, size.height - bubble.height - _margin));
    Rect? durationRect;
    if (hasChild(_TimeBubbleSlot.duration)) {
      final bubble = layoutChild(_TimeBubbleSlot.duration, constraints);
      final record = geometry.record;
      final radius = record.width / 2;
      final radial = geometry.tip(1, 0) - record.center;
      final edge = record.center + radial / radial.distance * radius;
      final left = fitX(edge.dx - bubble.width / 2, bubble);
      // Keep the entire bubble outside the circular edge, even on small decks.
      final nearestX = record.center.dx.clamp(left, left + bubble.width);
      final dx = nearestX - record.center.dx;
      final boundaryY =
          record.center.dy + math.sqrt(math.max(0, radius * radius - dx * dx));
      final top = fitY(math.max(edge.dy + 12, boundaryY + 8), bubble);
      durationRect = Rect.fromLTWH(left, top, bubble.width, bubble.height);
      positionChild(_TimeBubbleSlot.duration, durationRect.topLeft);
    }
    if (hasChild(_TimeBubbleSlot.position)) {
      final bubble = layoutChild(_TimeBubbleSlot.position, constraints);
      var offset = Offset(fitX(needle.dx - bubble.width / 2, bubble),
          fitY(needle.dy - bubble.height - 18, bubble));
      if (durationRect != null &&
          (offset & bubble).overlaps(durationRect.inflate(8))) {
        final left = durationRect.left - bubble.width - 8;
        offset = left >= _margin
            ? Offset(left, offset.dy)
            : Offset(
                offset.dx, fitY(durationRect.top - bubble.height - 8, bubble));
      }
      positionChild(_TimeBubbleSlot.position, offset);
    }
  }

  @override
  bool shouldRelayout(_TimeBubbleLayout oldDelegate) =>
      geometry.size != oldDelegate.geometry.size ||
      needle != oldDelegate.needle;
}

class VinylRecord extends StatefulWidget {
  const VinylRecord(
      {super.key,
      required this.playing,
      required this.cover,
      this.position = Duration.zero});
  final bool playing;
  final Widget cover;
  final Duration position;
  @override
  State<VinylRecord> createState() => _VinylRecordState();
}

class _VinylRecordState extends State<VinylRecord>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController.unbounded(vsync: this);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(VinylRecord oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position ||
        oldWidget.playing != widget.playing) {
      _sync();
    }
  }

  void _sync() {
    // Re-anchor to audio time; interpolate at one revolution per minute
    // between the audio engine's position updates.
    final turns =
        widget.position.inMicroseconds / vinylRevolution.inMicroseconds;
    _spin.stop();
    _spin.value = turns;
    if (widget.playing && !MediaQuery.of(context).disableAnimations) {
      _spin.animateTo(turns + 1,
          duration: vinylRevolution, curve: Curves.linear);
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
          child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) =>
            Transform.rotate(angle: _spin.value * math.pi * 2, child: child),
        child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 7))
            ]),
            child: Stack(alignment: Alignment.center, children: [
              const Positioned.fill(
                  child: CustomPaint(painter: _RecordPainter())),
              FractionallySizedBox(
                  widthFactor: .35,
                  heightFactor: .35,
                  child: ClipOval(child: widget.cover)),
              FractionallySizedBox(
                  widthFactor: .35,
                  heightFactor: .35,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(.18),
                              width: 3)))),
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC7C6BC),
                      border: Border.all(
                          color: const Color(0xFF131713), width: 3))),
            ])),
      ));
}

class _RecordEdgePainter extends CustomPainter {
  const _RecordEdgePainter(this.direction);
  final int direction;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(direction < 0 ? size.width : 0, size.height / 2);
    final rim = Rect.fromCircle(center: center, radius: size.height / 2 - 4);
    final start = (direction < 0 ? math.pi : 0) - .7;
    const red = Color(0xFFE76A5D);
    canvas.drawArc(
        rim,
        start,
        1.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 12
          ..color = red.withOpacity(.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawArc(
        rim,
        start,
        1.4,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.5
          ..color = red);
  }

  @override
  bool shouldRepaint(_RecordEdgePainter oldDelegate) =>
      oldDelegate.direction != direction;
}

class _RecordPainter extends CustomPainter {
  const _RecordPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
              colors: [Color(0xFF323732), Color(0xFF111512), Color(0xFF252A25)],
              stops: [0, .8, 1]).createShader(Offset.zero & size));
    for (double r = .20; r < .99; r += .013) {
      canvas.drawCircle(
          center,
          radius * r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6
            ..color = Colors.white.withOpacity(r > .92 ? .09 : .055));
    }
    for (final angle in [-.9, math.pi - .9]) {
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * .7),
          angle,
          .38,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * .5
            ..shader = SweepGradient(colors: [
              Colors.white.withOpacity(.0),
              Colors.white.withOpacity(.11),
              Colors.white.withOpacity(.0)
            ]).createShader(Offset.zero & size));
    }
    canvas.drawCircle(
        center,
        radius * .98,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = const Color(0xFF555B50));
  }

  @override
  bool shouldRepaint(_RecordPainter oldDelegate) => false;
}

// The arm and its cradle share the same parked cartridge geometry.
Offset _armPivot(Size size) => VinylDeckGeometry(size).pivot;
Offset _armTip(Size size, double lowered, double progress) =>
    VinylDeckGeometry(size).tip(lowered, progress);
Offset _armElbow(Size size, Offset tip) => VinylDeckGeometry(size).elbow(tip);
double _cartridgeAngle(Size size, Offset tip) {
  final elbow = _armElbow(size, tip);
  return math.atan2(tip.dy - elbow.dy, tip.dx - elbow.dx) - math.pi / 2;
}

class _PlinthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(9);
    for (var i = 0; i < 95; i++) {
      final y = random.nextDouble() * size.height;
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(
            size.width * .35, y - 3, size.width * .7, y + 3, size.width, y);
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = random.nextDouble() + .3
            ..color =
                Colors.black.withOpacity(.025 + random.nextDouble() * .025));
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(7, 7, size.width - 14, size.height - 14),
            const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white.withOpacity(.09));
    for (final p in [const Offset(16, 16), Offset(size.width - 16, 16)]) {
      canvas.drawCircle(p, 2.3, Paint()..color = const Color(0xFFBDA98A));
    }
    final parkedTip = _armTip(size, 0, 0);
    canvas.save();
    canvas.translate(parkedTip.dx, parkedTip.dy);
    canvas.rotate(_cartridgeAngle(size, parkedTip));
    final cradle = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -33, 22, 38), const Radius.circular(5));
    canvas.drawRRect(cradle, Paint()..color = const Color(0xFF352D25));
    canvas.drawRRect(
        cradle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFAB9470));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlinthPainter oldDelegate) => false;
}

class _TonearmPainter extends CustomPainter {
  _TonearmPainter(this.lowered, this.progress, {this.lifted = false});
  final double lowered;
  final double progress;
  final bool lifted;
  Size? _size;
  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final pivot = _armPivot(size);
    final tip =
        VinylDeckGeometry(size).needleTip(lowered, progress, lifted: lifted);
    final elbow = _armElbow(size, tip);
    final armEnd = tip - (tip - elbow) / (tip - elbow).distance * 20;
    final path = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(armEnd.dx, armEnd.dy);
    canvas.drawPath(
        path.shift(Offset(lifted ? 7 : 4, lifted ? 12 : 6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withOpacity(.28));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF3A3C34));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = const LinearGradient(colors: [
            Color(0xFFF0E3C5),
            Color(0xFFB89D6C),
            Color(0xFFE9D6AF)
          ]).createShader(Offset.zero & size));
    canvas.drawCircle(pivot, 17, Paint()..color = const Color(0xFF35372F));
    canvas.drawCircle(
        pivot,
        12,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFFE6D7B6), Color(0xFF97815A)])
              .createShader(Rect.fromCircle(center: pivot, radius: 12)));
    canvas.drawCircle(pivot, 4, Paint()..color = const Color(0xFF655A42));
    canvas.save();
    canvas.translate(tip.dx + (lifted ? 7 : 4), tip.dy + (lifted ? 12 : 6));
    canvas.rotate(_cartridgeAngle(size, tip));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-8, -30, 16, 27), const Radius.circular(3)),
        Paint()..color = Colors.black.withOpacity(lifted ? .4 : .25));
    canvas.restore();
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(_cartridgeAngle(size, tip));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-8, -30, 16, 27), const Radius.circular(3)),
        Paint()..color = const Color(0xFF212820));
    canvas.drawRect(
        const Rect.fromLTWH(-5, -14, 10, 8), Paint()..color = vinylGold);
    canvas.drawLine(
        const Offset(0, -6),
        Offset.zero,
        Paint()
          ..strokeWidth = 2
          ..color = const Color(0xFFECE4D0));
    canvas.restore();
  }

  @override
  bool? hitTest(Offset position) {
    if (_size == null) return false;
    final pivot = _armPivot(_size!);
    final tip =
        VinylDeckGeometry(_size!).needleTip(lowered, progress, lifted: lifted);
    final elbow = _armElbow(_size!, tip);
    double distanceToSegment(Offset start, Offset end) {
      final vector = end - start;
      final projection = ((position - start).dx * vector.dx +
              (position - start).dy * vector.dy) /
          vector.distanceSquared;
      return (position - (start + vector * projection.clamp(0.0, 1.0)))
          .distance;
    }

    return distanceToSegment(pivot, elbow) < 24 ||
        distanceToSegment(elbow, tip) < 24;
  }

  @override
  bool shouldRepaint(_TonearmPainter oldDelegate) =>
      oldDelegate.lowered != lowered ||
      oldDelegate.progress != progress ||
      oldDelegate.lifted != lifted;
}
