import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'penalty_motion_timeline.dart';

/// Full-body layout used by both arenas, including the rotated keeper bounds.
class PenaltyActorLayout {
  PenaltyActorLayout(
      {required Size size,
      required Rect goal,
      required Offset keeperTarget,
      required PenaltyMotionFrame frame}) {
    // Defensive rendering also protects local callers from malformed targets.
    keeperTarget = Offset(
        keeperTarget.dx.isFinite
            ? keeperTarget.dx.clamp(0.0, 1.0).toDouble()
            : .5,
        keeperTarget.dy.isFinite
            ? keeperTarget.dy.clamp(0.0, 1.0).toDouble()
            : .5);
    final approach = frame.approach;
    final playerHeight =
        math.min(size.height * (.205 - approach * .018), size.width * .34);
    final playerWidth = playerHeight * 2 / 3;
    final x =
        size.width * (.355 + approach * .105 + frame.followThrough * .012);
    final feet = size.height * (.86 - approach * .043);
    playerRect = Rect.fromLTWH(
        x - playerWidth / 2,
        feet -
            playerHeight -
            math.sin(frame.followThrough * math.pi) * playerHeight * .025,
        playerWidth,
        playerHeight);
    runBlend = math.sin(approach * math.pi) * (1 - frame.plant);
    kickBlend = frame.plant;
    // The kick asset's raised boot is at (94%,54%). Rotate the contact
    // pose around that boot, then let it rise naturally in follow-through.
    final ball = Offset(size.width * .5, size.height * .805);
    final ballRadius = math.min(size.width * .041, size.height * .045);
    kickPosition = ball +
        Offset(-ballRadius * .7 - (1 - frame.plant) * playerHeight * .16,
            ballRadius * .05 + (1 - frame.plant) * playerHeight * .06) -
        Offset(-frame.followThrough * playerHeight * .12,
            frame.followThrough * playerHeight * .28);
    kickRotation = (.65 - frame.contact * .06) * (1 - frame.followThrough);
    kickRect = Rect.fromLTWH(
        -playerWidth * .94, -playerHeight * .54, playerWidth, playerHeight);
    final kickCorners = [
      kickRect.topLeft,
      kickRect.topRight,
      kickRect.bottomLeft,
      kickRect.bottomRight
    ].map((p) =>
        Offset(p.dx * math.cos(kickRotation) - p.dy * math.sin(kickRotation),
            p.dx * math.sin(kickRotation) + p.dy * math.cos(kickRotation)) +
        kickPosition);
    kickBounds = Rect.fromLTRB(
        kickCorners.map((p) => p.dx).reduce(math.min),
        kickCorners.map((p) => p.dy).reduce(math.min),
        kickCorners.map((p) => p.dx).reduce(math.max),
        kickCorners.map((p) => p.dy).reduce(math.max));
    final dir = keeperTarget.dx - .5;
    final reach = dir.abs();
    final t = frame.keeperPush * .28 + frame.keeperReach * .72;
    keeperRotation = dir * .07 * t;
    keeperDiveBlend = (frame.keeperPush * .25 + frame.keeperReach * .75) *
        (reach / .12).clamp(0.0, 1.0);
    final fit = math.min(1.0, size.width * .88 / (goal.height * 1.16));
    final readyHeight = goal.height * .54 * fit;
    final readyWidth = readyHeight * .67;
    final diveWidth = goal.height * (1.02 + reach * .16) * fit;
    final diveHeight = diveWidth / 1.5;
    readyRect = Rect.fromCenter(
        center: Offset(0, -readyHeight * .1),
        width: readyWidth,
        height: readyHeight);
    diveRect = Rect.fromCenter(
        center: Offset(0, -diveHeight * .05),
        width: diveWidth,
        height: diveHeight);
    final both = readyRect.expandToInclude(diveRect);
    final corners = [
      both.topLeft,
      both.topRight,
      both.bottomLeft,
      both.bottomRight
    ].map((p) => Offset(
        p.dx * math.cos(keeperRotation) - p.dy * math.sin(keeperRotation),
        p.dx * math.sin(keeperRotation) + p.dy * math.cos(keeperRotation)));
    final xs = corners.map((p) => p.dx);
    final ys = corners.map((p) => p.dy);
    final localBounds = Rect.fromLTRB(xs.reduce(math.min), ys.reduce(math.min),
        xs.reduce(math.max), ys.reduce(math.max));
    final start = Offset(goal.center.dx, goal.top + goal.height * .67);
    final target = Offset(goal.left + keeperTarget.dx * goal.width,
        goal.top + keeperTarget.dy * goal.height);
    final raw = Offset.lerp(start, target, t)! +
        Offset(
            0,
            -math.sin(t * math.pi) *
                    goal.height *
                    .065 *
                    (1 - frame.keeperLanding) +
                frame.keeperLanding * goal.height * .13);
    keeperCenter = Offset(
        raw.dx
            .clamp(-localBounds.left, size.width - localBounds.right)
            .toDouble(),
        raw.dy
            .clamp(-localBounds.top, size.height - localBounds.bottom)
            .toDouble());
    keeperBounds = localBounds.shift(keeperCenter);
    mirrorKeeper = dir < 0;
  }
  Offset get kickFootPosition => kickPosition;
  late final Rect kickBounds, kickRect;
  late final Offset kickPosition;
  late final double kickRotation;
  late final Rect playerRect, readyRect, diveRect, keeperBounds;
  late final Offset keeperCenter;
  late final double keeperRotation, keeperDiveBlend, runBlend, kickBlend;
  late final bool mirrorKeeper;
}

class PenaltyActorPainter {
  const PenaltyActorPainter(
      {required this.keeperReady,
      required this.keeperDive,
      required this.playerReady,
      required this.playerRun,
      required this.playerKick});
  final ui.Image keeperReady, keeperDive, playerReady, playerRun, playerKick;

  static Future<PenaltyActorPainter> load() async {
    Future<ui.Image> image(String path) async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    }

    final images = await Future.wait([
      image('assets/football/keeper_pro_v2.png'),
      image('assets/football/keeper_dive_pro_v2.png'),
      image('assets/football/player_ready_pro_v2.png'),
      image('assets/football/player_run_pro_v2.png'),
      image('assets/football/player_kick_pro_v2.png')
    ]);
    return PenaltyActorPainter(
        keeperReady: images[0],
        keeperDive: images[1],
        playerReady: images[2],
        playerRun: images[3],
        playerKick: images[4]);
  }

  void _pose(Canvas canvas, ui.Image image, Rect destination, double opacity) {
    if (opacity <= 0) return;
    canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        destination,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high
          ..color =
              Colors.white.withAlpha((opacity.clamp(0.0, 1.0) * 255).round()));
  }

  void paintKeeper(Canvas canvas, PenaltyActorLayout layout) {
    canvas.save();
    canvas.translate(layout.keeperCenter.dx, layout.keeperCenter.dy);
    canvas.rotate(layout.keeperRotation);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, layout.readyRect.height * .53),
            width: layout.diveRect.width * .7,
            height: layout.readyRect.height * .1),
        Paint()
          ..color = Colors.black.withAlpha(100)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    _pose(canvas, keeperReady, layout.readyRect, 1 - layout.keeperDiveBlend);
    if (layout.mirrorKeeper) canvas.scale(-1, 1);
    _pose(canvas, keeperDive, layout.diveRect, layout.keeperDiveBlend);
    canvas.restore();
  }

  void paintPlayer(Canvas canvas, PenaltyActorLayout layout) {
    final rect = layout.playerRect;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(rect.center.dx, rect.bottom + rect.height * .018),
            width: rect.width * .82,
            height: rect.height * .075),
        Paint()
          ..color = Colors.black.withAlpha(105)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    _pose(canvas, playerReady, rect,
        1 - math.max(layout.runBlend, layout.kickBlend));
    _pose(canvas, playerRun, rect, layout.runBlend * (1 - layout.kickBlend));
    canvas.save();
    canvas.translate(layout.kickPosition.dx, layout.kickPosition.dy);
    canvas.rotate(layout.kickRotation);
    _pose(canvas, playerKick, layout.kickRect, layout.kickBlend);
    canvas.restore();
  }
}
