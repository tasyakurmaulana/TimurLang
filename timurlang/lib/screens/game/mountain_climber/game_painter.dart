// ============================================
// TimurLang - Mountain Climber Game Painter
// CustomPainter for rendering game visuals
// ============================================

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'game_constants.dart';
import 'game_models.dart';
import 'game_engine.dart';

class GamePainter extends CustomPainter {
  final GameEngine engine;
  final bool showVectorPlayer;

  GamePainter(this.engine, {this.showVectorPlayer = true});

  @override
  void paint(Canvas canvas, Size size) {
    _drawSky(canvas, size);
    _drawStars(canvas, size);
    _drawFarMountains(canvas, size);
    _drawNearMountains(canvas, size);
    _drawFog(canvas, size);
    _drawTrees(canvas, size);
    _drawGround(canvas, size);
    _drawObstacles(canvas, size);
    if (showVectorPlayer) {
      _drawPlayer(canvas, size);
    }

    if (engine.status == GameStatus.ready) {
      _drawReadyOverlay(canvas, size);
    } else if (engine.status == GameStatus.gameOver) {
      _drawGameOverOverlay(canvas, size);
    }
  }

  // ── Sky Rendering ──
  void _drawSky(Canvas canvas, Size size) {
    List<Color> currentColors;
    List<Color> nextColors;
    double t;

    switch (engine.skyPhase) {
      case SkyPhase.pagi:
        currentColors = GameConstants.pagiSkyColors;
        nextColors = GameConstants.senjaSkyColors;
        t = engine.skyTransitionProgress;
        break;
      case SkyPhase.senja:
        currentColors = GameConstants.senjaSkyColors;
        nextColors = GameConstants.malamSkyColors;
        t = engine.skyTransitionProgress;
        break;
      case SkyPhase.malam:
        currentColors = GameConstants.malamSkyColors;
        nextColors = GameConstants.pagiSkyColors;
        t = engine.skyTransitionProgress;
        break;
    }

    final colors = List.generate(3, (i) {
      return Color.lerp(currentColors[i], nextColors[i], t)!;
    });

    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        colors,
        [0.0, 0.5, 1.0],
      );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);
  }

  // ── Stars (visible during senja/malam) ──
  void _drawStars(Canvas canvas, Size size) {
    double starOpacity = 0.0;
    final t = engine.skyTransitionProgress;

    switch (engine.skyPhase) {
      case SkyPhase.pagi:
        starOpacity = t > 0.5 ? (t - 0.5) * 0.4 : 0.0;
        break;
      case SkyPhase.senja:
        starOpacity = 0.2 + (0.6 * t);
        break;
      case SkyPhase.malam:
        starOpacity = 1.0 - (0.8 * t);
        break;
    }

    if (starOpacity <= 0.01) return;

    for (var star in engine.stars) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: (star.brightness * starOpacity).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  // ── Far Mountains (siluet pegunungan jauh) ──
  void _drawFarMountains(Canvas canvas, Size size) {
    final groundY = engine.groundY;
    final baseY = groundY - size.height * 0.05;
    final offset = engine.farMountains.offset % (size.width * 2);

    final mountainColor = Color.lerp(
      const Color(0xFF5C7A8A).withValues(alpha: 0.4),
      const Color(0xFF1A1A3E).withValues(alpha: 0.6),
      engine.darkness,
    )!;

    final path = Path();
    path.moveTo(0, baseY);

    for (double x = -offset; x < size.width + 200; x += 160) {
      final segIndex =
          ((x + offset) / 160).floor() % engine.farMountains.segments.length;
      final h = engine.farMountains.segments[segIndex.abs()] * size.height * 0.25;
      path.lineTo(x, baseY - h * 0.6);
      path.lineTo(x + 80, baseY - h);
      path.lineTo(x + 160, baseY - h * 0.5);
    }

    path.lineTo(size.width + 200, baseY);
    path.lineTo(size.width + 200, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Add snow caps for far mountains
    canvas.drawPath(path, Paint()..color = mountainColor);

    // Draw subtle snow caps
    if (engine.darkness < 0.6) {
      final snowPath = Path();
      for (double x = -offset; x < size.width + 200; x += 160) {
        final segIndex =
            ((x + offset) / 160).floor() % engine.farMountains.segments.length;
        final h = engine.farMountains.segments[segIndex.abs()] * size.height * 0.25;
        if (h > size.height * 0.15) {
          snowPath.moveTo(x + 70, baseY - h + 10);
          snowPath.lineTo(x + 80, baseY - h);
          snowPath.lineTo(x + 90, baseY - h + 10);
          snowPath.close();
        }
      }
      canvas.drawPath(snowPath, Paint()..color = Colors.white.withValues(alpha: 0.3));
    }
  }

  // ── Near Mountains ──
  void _drawNearMountains(Canvas canvas, Size size) {
    final groundY = engine.groundY;
    final baseY = groundY + 5;
    final offset = engine.nearMountains.offset % (size.width * 1.5);

    final mountainColor = Color.lerp(
      const Color(0xFF3E6B5A).withValues(alpha: 0.6),
      const Color(0xFF151530).withValues(alpha: 0.7),
      engine.darkness,
    )!;

    final path = Path();
    path.moveTo(0, baseY);

    for (double x = -offset; x < size.width + 200; x += 120) {
      final segIndex =
          ((x + offset) / 120).floor() % engine.nearMountains.segments.length;
      final h = engine.nearMountains.segments[segIndex.abs()] * size.height * 0.18;
      path.lineTo(x + 30, baseY - h * 0.4);
      path.lineTo(x + 60, baseY - h);
      path.lineTo(x + 90, baseY - h * 0.6);
      path.lineTo(x + 120, baseY - h * 0.3);
    }

    path.lineTo(size.width + 200, baseY);
    path.lineTo(size.width + 200, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = mountainColor);
  }

  // ── Fog Layer ──
  void _drawFog(Canvas canvas, Size size) {
    final groundY = engine.groundY;
    final offset = engine.fog.offset % (size.width * 3);

    final fogOpacity = ui.lerpDouble(0.15, 0.08, engine.darkness)!;

    final fogPaint = Paint()
      ..color = Colors.white.withValues(alpha: fogOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    // Draw multiple fog bands
    for (int i = 0; i < 3; i++) {
      final fogY = groundY - size.height * 0.1 - i * 30;
      final fogX = -offset + i * 100;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(fogX % size.width, fogY),
          width: size.width * 0.6,
          height: 25,
        ),
        fogPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset((fogX + size.width * 0.7) % (size.width * 1.5), fogY - 10),
          width: size.width * 0.5,
          height: 20,
        ),
        fogPaint,
      );
    }
  }

  // ── Trees (Pohon Cemara/Pinus) ──
  void _drawTrees(Canvas canvas, Size size) {
    final groundY = engine.groundY;
    final offset = engine.trees.offset % (size.width * 2);

    final treeColor = Color.lerp(
      const Color(0xFF1B5E20),
      const Color(0xFF0A1F0A),
      engine.darkness,
    )!;
    final trunkColor = Color.lerp(
      const Color(0xFF4E342E),
      const Color(0xFF1B1210),
      engine.darkness,
    )!;

    for (double x = -offset; x < size.width + 100; x += 85) {
      final segIndex =
          ((x + offset) / 85).floor().abs() % engine.trees.segments.length;
      final treeHeight = 35 + engine.trees.segments[segIndex] * 45;
      final treeX = x;
      final treeBaseY = groundY;

      // Draw trunk
      canvas.drawRect(
        Rect.fromLTWH(treeX + 8, treeBaseY - treeHeight * 0.35, 5, treeHeight * 0.35),
        Paint()..color = trunkColor,
      );

      // Draw pine tree layers (triangles)
      final treePath = Path();
      for (int layer = 0; layer < 3; layer++) {
        final layerY = treeBaseY - treeHeight * 0.3 - layer * treeHeight * 0.22;
        final layerWidth = 22.0 - layer * 4;
        treePath.moveTo(treeX + 10.5 - layerWidth / 2, layerY);
        treePath.lineTo(treeX + 10.5, layerY - treeHeight * 0.28);
        treePath.lineTo(treeX + 10.5 + layerWidth / 2, layerY);
        treePath.close();
      }
      canvas.drawPath(treePath, Paint()..color = treeColor);
    }
  }

  // ── Ground ──
  void _drawGround(Canvas canvas, Size size) {
    final groundY = engine.groundY;

    // Main ground
    final groundColor = Color.lerp(
      const Color(0xFF5D4037),
      const Color(0xFF1A0F0A),
      engine.darkness,
    )!;
    final groundDetailColor = Color.lerp(
      const Color(0xFF795548),
      const Color(0xFF2E1F14),
      engine.darkness,
    )!;

    // Draw main ground rect
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      Paint()..color = groundColor,
    );

    // Ground surface line
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = groundDetailColor
        ..strokeWidth = 3,
    );

    // Draw ground texture dots
    final groundOffset = engine.trees.offset;
    final detailPaint = Paint()..color = groundDetailColor.withValues(alpha: 0.4);
    for (double x = -(groundOffset % 30); x < size.width; x += 30) {
      canvas.drawCircle(Offset(x, groundY + 8), 2, detailPaint);
      canvas.drawCircle(Offset(x + 15, groundY + 18), 1.5, detailPaint);
    }

    // Small rocks/pebbles on ground
    final pebblePaint = Paint()..color = groundDetailColor.withValues(alpha: 0.5);
    for (double x = -(groundOffset % 60); x < size.width; x += 60) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 20, groundY + 12), width: 6, height: 3),
        pebblePaint,
      );
    }
  }

  // ── Obstacles ──
  void _drawObstacles(Canvas canvas, Size size) {
    for (var obstacle in engine.obstacles) {
      if (obstacle.type == ObstacleType.bawah) {
        _drawBottomObstacle(canvas, obstacle);
      } else {
        _drawTopObstacle(canvas, obstacle);
      }
    }
  }

  void _drawBottomObstacle(Canvas canvas, Obstacle obstacle) {
    final isDark = engine.mdpl > GameConstants.malamThreshold;

    switch (obstacle.name) {
      case 'rubah':
      case 'batu_cadas':
        _drawRock(canvas, obstacle, isDark);
        break;
      case 'kayu':
        _drawRollingWood(canvas, obstacle, isDark);
        break;
      case 'pohon_tumbang':
        _drawFallenTree(canvas, obstacle, isDark);
        break;
      case 'jurang_kecil':
        _drawSmallCliff(canvas, obstacle, isDark);
        break;
      case 'tenda_rusak':
        _drawBrokenTent(canvas, obstacle, isDark);
        break;
      default:
        _drawRock(canvas, obstacle, isDark);
        break;
    }
  }

  void _drawTopObstacle(Canvas canvas, Obstacle obstacle) {
    final isDark = engine.mdpl > GameConstants.malamThreshold;

    switch (obstacle.name) {
      case 'elang':
        _drawEagle(canvas, obstacle, isDark);
        break;
      case 'dahan_pinus':
        _drawPineBranch(canvas, obstacle, isDark);
        break;
      case 'batu_jatuh':
        _drawFallingRock(canvas, obstacle, isDark);
        break;
    }
  }

  void _drawRock(Canvas canvas, Obstacle obs, bool isDark) {
    final baseColor = isDark ? const Color(0xFF3E3E3E) : const Color(0xFF78909C);
    final highlightColor = isDark ? const Color(0xFF5E5E5E) : const Color(0xFF90A4AE);

    final path = Path();
    path.moveTo(obs.x + obs.width * 0.1, obs.y + obs.height);
    path.lineTo(obs.x + obs.width * 0.05, obs.y + obs.height * 0.5);
    path.lineTo(obs.x + obs.width * 0.25, obs.y + obs.height * 0.15);
    path.lineTo(obs.x + obs.width * 0.5, obs.y);
    path.lineTo(obs.x + obs.width * 0.8, obs.y + obs.height * 0.2);
    path.lineTo(obs.x + obs.width * 0.95, obs.y + obs.height * 0.55);
    path.lineTo(obs.x + obs.width * 0.9, obs.y + obs.height);
    path.close();

    canvas.drawPath(path, Paint()..color = baseColor);

    // Highlight
    final highlightPath = Path();
    highlightPath.moveTo(obs.x + obs.width * 0.3, obs.y + obs.height * 0.3);
    highlightPath.lineTo(obs.x + obs.width * 0.5, obs.y + obs.height * 0.1);
    highlightPath.lineTo(obs.x + obs.width * 0.6, obs.y + obs.height * 0.35);
    highlightPath.close();
    canvas.drawPath(highlightPath, Paint()..color = highlightColor.withValues(alpha: 0.5));
  }

  void _drawRollingWood(Canvas canvas, Obstacle obs, bool isDark) {
    final radius = obs.width / 2.0;
    final center = Offset(obs.x + radius, obs.y + radius);

    // Contact shadow on ground
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, obs.y + obs.height - 0.5),
        width: obs.width * 0.78,
        height: 4.5,
      ),
      shadowPaint,
    );

    // Dynamic rotation angle from movement
    final rotation = -obs.x / radius;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final barkColor = isDark ? const Color(0xFF3E2723) : const Color(0xFF5D4037);
    final woodColor = isDark ? const Color(0xFFBCAAA4) : const Color(0xFFD7CCC8);
    final ringColor = isDark ? const Color(0xFF8D6E63) : const Color(0xFFA1887F);

    canvas.drawCircle(Offset.zero, radius, Paint()..color = barkColor);
    canvas.drawCircle(Offset.zero, radius * 0.88, Paint()..color = woodColor);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(Offset.zero, radius * 0.60, ringPaint);
    canvas.drawCircle(Offset.zero, radius * 0.32, ringPaint);

    final crackPaint = Paint()
      ..color = barkColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(radius * 0.75, 0), crackPaint);
    canvas.drawLine(Offset.zero, Offset(-radius * 0.5, radius * 0.5), crackPaint);

    canvas.restore();
  }

  void _drawFallenTree(Canvas canvas, Obstacle obs, bool isDark) {
    final trunkColor = isDark ? const Color(0xFF3E2723) : const Color(0xFF5D4037);
    final barkColor = isDark ? const Color(0xFF4E342E) : const Color(0xFF6D4C41);

    // Main trunk
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(obs.x, obs.y + obs.height * 0.3, obs.width, obs.height * 0.5),
        const Radius.circular(6),
      ),
      Paint()..color = trunkColor,
    );

    // Bark detail lines
    final barkPaint = Paint()
      ..color = barkColor
      ..strokeWidth = 1.5;
    for (double dx = obs.x + 8; dx < obs.x + obs.width - 8; dx += 12) {
      canvas.drawLine(
        Offset(dx, obs.y + obs.height * 0.35),
        Offset(dx, obs.y + obs.height * 0.75),
        barkPaint,
      );
    }

    // Broken branches
    final branchPaint = Paint()
      ..color = trunkColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(obs.x + obs.width * 0.2, obs.y + obs.height * 0.3),
      Offset(obs.x + obs.width * 0.15, obs.y),
      branchPaint,
    );
    canvas.drawLine(
      Offset(obs.x + obs.width * 0.7, obs.y + obs.height * 0.3),
      Offset(obs.x + obs.width * 0.75, obs.y + obs.height * 0.05),
      branchPaint,
    );
  }

  void _drawSmallCliff(Canvas canvas, Obstacle obs, bool isDark) {
    final cliffColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFF5D4037);
    final darkColor = isDark ? const Color(0xFF1A1A1A) : const Color(0xFF3E2723);

    // Gap/cliff opening
    canvas.drawRect(
      Rect.fromLTWH(obs.x + 4, obs.y, obs.width - 8, obs.height),
      Paint()..color = darkColor,
    );

    // Cliff edges
    final leftPath = Path();
    leftPath.moveTo(obs.x, obs.y);
    leftPath.lineTo(obs.x + 8, obs.y);
    leftPath.lineTo(obs.x + 5, obs.y + obs.height);
    leftPath.lineTo(obs.x, obs.y + obs.height);
    leftPath.close();
    canvas.drawPath(leftPath, Paint()..color = cliffColor);

    final rightPath = Path();
    rightPath.moveTo(obs.x + obs.width - 8, obs.y);
    rightPath.lineTo(obs.x + obs.width, obs.y);
    rightPath.lineTo(obs.x + obs.width, obs.y + obs.height);
    rightPath.lineTo(obs.x + obs.width - 5, obs.y + obs.height);
    rightPath.close();
    canvas.drawPath(rightPath, Paint()..color = cliffColor);
  }

  void _drawBrokenTent(Canvas canvas, Obstacle obs, bool isDark) {
    final tentColor = isDark ? const Color(0xFF4A148C) : const Color(0xFFE65100);
    final poleColor = isDark ? const Color(0xFF3E3E3E) : const Color(0xFF757575);

    // Collapsed tent fabric
    final tentPath = Path();
    tentPath.moveTo(obs.x, obs.y + obs.height);
    tentPath.lineTo(obs.x + obs.width * 0.3, obs.y + obs.height * 0.15);
    tentPath.lineTo(obs.x + obs.width * 0.5, obs.y + obs.height * 0.5);
    tentPath.lineTo(obs.x + obs.width * 0.7, obs.y);
    tentPath.lineTo(obs.x + obs.width, obs.y + obs.height);
    tentPath.close();
    canvas.drawPath(tentPath, Paint()..color = tentColor);

    // Tent pole sticking out
    canvas.drawLine(
      Offset(obs.x + obs.width * 0.7, obs.y),
      Offset(obs.x + obs.width * 0.65, obs.y - 10),
      Paint()
        ..color = poleColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawEagle(Canvas canvas, Obstacle obs, bool isDark) {
    final bodyColor = isDark ? const Color(0xFF2E2E2E) : const Color(0xFF4E342E);
    final wingColor = isDark ? const Color(0xFF3E3E3E) : const Color(0xFF5D4037);

    final cx = obs.x + obs.width / 2;
    final cy = obs.y + obs.height / 2;

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: obs.width * 0.35, height: obs.height * 0.5),
      Paint()..color = bodyColor,
    );

    // Wings (animated flap effect based on x position)
    final flapAngle = sin(obs.x * 0.05) * 0.3;

    // Left wing
    final leftWing = Path();
    leftWing.moveTo(cx - 5, cy);
    leftWing.quadraticBezierTo(
      cx - obs.width * 0.4, cy - obs.height * (0.4 + flapAngle),
      cx - obs.width * 0.5, cy - obs.height * 0.1,
    );
    leftWing.lineTo(cx - 5, cy + 3);
    leftWing.close();
    canvas.drawPath(leftWing, Paint()..color = wingColor);

    // Right wing
    final rightWing = Path();
    rightWing.moveTo(cx + 5, cy);
    rightWing.quadraticBezierTo(
      cx + obs.width * 0.4, cy - obs.height * (0.4 + flapAngle),
      cx + obs.width * 0.5, cy - obs.height * 0.1,
    );
    rightWing.lineTo(cx + 5, cy + 3);
    rightWing.close();
    canvas.drawPath(rightWing, Paint()..color = wingColor);

    // Head
    canvas.drawCircle(
      Offset(cx + obs.width * 0.1, cy - obs.height * 0.15),
      4,
      Paint()..color = bodyColor,
    );

    // Beak
    canvas.drawLine(
      Offset(cx + obs.width * 0.15, cy - obs.height * 0.15),
      Offset(cx + obs.width * 0.22, cy - obs.height * 0.1),
      Paint()
        ..color = const Color(0xFFFFAB00)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawPineBranch(Canvas canvas, Obstacle obs, bool isDark) {
    final branchColor = isDark ? const Color(0xFF2E1F14) : const Color(0xFF5D4037);
    final leafColor = isDark ? const Color(0xFF0A1F0A) : const Color(0xFF2E7D32);

    // Main branch
    canvas.drawLine(
      Offset(obs.x, obs.y + obs.height * 0.5),
      Offset(obs.x + obs.width, obs.y + obs.height * 0.4),
      Paint()
        ..color = branchColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Pine needle clusters
    for (double dx = 0.1; dx < 0.9; dx += 0.2) {
      final bx = obs.x + obs.width * dx;
      final by = obs.y + obs.height * (0.5 - dx * 0.1);
      final needlePath = Path();
      needlePath.moveTo(bx, by - obs.height * 0.4);
      needlePath.lineTo(bx - 8, by + 3);
      needlePath.lineTo(bx + 8, by + 3);
      needlePath.close();
      canvas.drawPath(needlePath, Paint()..color = leafColor);
    }
  }

  void _drawFallingRock(Canvas canvas, Obstacle obs, bool isDark) {
    final rockColor = isDark ? const Color(0xFF424242) : const Color(0xFF616161);
    final highlightColor = isDark ? const Color(0xFF616161) : const Color(0xFF9E9E9E);

    // Main rock shape
    final path = Path();
    path.moveTo(obs.x + obs.width * 0.2, obs.y);
    path.lineTo(obs.x + obs.width * 0.8, obs.y + obs.height * 0.1);
    path.lineTo(obs.x + obs.width, obs.y + obs.height * 0.5);
    path.lineTo(obs.x + obs.width * 0.85, obs.y + obs.height);
    path.lineTo(obs.x + obs.width * 0.15, obs.y + obs.height * 0.9);
    path.lineTo(obs.x, obs.y + obs.height * 0.4);
    path.close();
    canvas.drawPath(path, Paint()..color = rockColor);

    // Highlight facet
    final facet = Path();
    facet.moveTo(obs.x + obs.width * 0.3, obs.y + obs.height * 0.2);
    facet.lineTo(obs.x + obs.width * 0.6, obs.y + obs.height * 0.15);
    facet.lineTo(obs.x + obs.width * 0.5, obs.y + obs.height * 0.5);
    facet.close();
    canvas.drawPath(facet, Paint()..color = highlightColor.withValues(alpha: 0.4));

    // Motion lines (falling effect)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(obs.x + obs.width * 0.3, obs.y - 5),
      Offset(obs.x + obs.width * 0.3, obs.y - 15),
      linePaint,
    );
    canvas.drawLine(
      Offset(obs.x + obs.width * 0.7, obs.y - 3),
      Offset(obs.x + obs.width * 0.7, obs.y - 12),
      linePaint,
    );
  }

  // ── Player (Pendaki with Carrier) ──
  void _drawPlayer(Canvas canvas, Size size) {
    final p = engine.player;
    final isDark = engine.mdpl > GameConstants.malamThreshold;

    if (engine.status == GameStatus.gameOver) {
      _drawPlayerDead(canvas, p, isDark);
      return;
    }

    switch (p.state) {
      case PlayerState.berlari:
        _drawPlayerRunning(canvas, p, isDark);
        break;
      case PlayerState.melompat:
        _drawPlayerJumping(canvas, p, isDark);
        break;
      case PlayerState.menunduk:
        _drawPlayerDucking(canvas, p, isDark);
        break;
    }
  }

  void _drawPlayerRunning(Canvas canvas, Player p, bool isDark) {
    final skinColor = isDark ? const Color(0xFFD7CCC8) : const Color(0xFFFFE0B2);
    final jacketColor = isDark ? const Color(0xFF1B5E20) : const Color(0xFFE65100);
    final pantsColor = isDark ? const Color(0xFF263238) : const Color(0xFF37474F);
    final carrierColor = isDark ? const Color(0xFF4A148C) : const Color(0xFF1565C0);
    final bootColor = isDark ? const Color(0xFF3E2723) : const Color(0xFF4E342E);
    final hatColor = isDark ? const Color(0xFF827717) : const Color(0xFFF57F17);

    final cx = p.x + p.width / 2;
    final runCycle = (p.animationFrame % 4).toInt();

    // ── Carrier/Backpack (behind body) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 6, p.y + 16, 18, 28),
        const Radius.circular(4),
      ),
      Paint()..color = carrierColor,
    );
    // Carrier straps
    canvas.drawLine(
      Offset(cx - 3, p.y + 16),
      Offset(cx - 5, p.y + 26),
      Paint()..color = carrierColor.withValues(alpha: 0.7)..strokeWidth = 2,
    );

    // ── Body/Jacket ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, p.y + 18, 16, 22),
        const Radius.circular(3),
      ),
      Paint()..color = jacketColor,
    );

    // ── Head ──
    canvas.drawCircle(Offset(cx - 2, p.y + 12), 10, Paint()..color = skinColor);

    // ── Hat ──
    final hatPath = Path();
    hatPath.moveTo(cx - 12, p.y + 10);
    hatPath.lineTo(cx - 2, p.y);
    hatPath.lineTo(cx + 8, p.y + 10);
    hatPath.close();
    canvas.drawPath(hatPath, Paint()..color = hatColor);

    // Hat brim
    canvas.drawLine(
      Offset(cx - 14, p.y + 10),
      Offset(cx + 10, p.y + 10),
      Paint()..color = hatColor..strokeWidth = 3..strokeCap = StrokeCap.round,
    );

    // ── Eyes ──
    canvas.drawCircle(Offset(cx - 5, p.y + 11), 1.5, Paint()..color = Colors.black);

    // ── Legs (animated) ──
    final legExtension1 = sin(runCycle * pi / 2) * 8;
    final legExtension2 = sin((runCycle + 2) * pi / 2) * 8;

    // Left leg
    canvas.drawLine(
      Offset(cx - 6, p.y + 40),
      Offset(cx - 6 + legExtension1, p.y + 56),
      Paint()..color = pantsColor..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    // Left boot
    canvas.drawCircle(
      Offset(cx - 6 + legExtension1, p.y + 58),
      4,
      Paint()..color = bootColor,
    );

    // Right leg
    canvas.drawLine(
      Offset(cx - 2, p.y + 40),
      Offset(cx - 2 + legExtension2, p.y + 56),
      Paint()..color = pantsColor..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    // Right boot
    canvas.drawCircle(
      Offset(cx - 2 + legExtension2, p.y + 58),
      4,
      Paint()..color = bootColor,
    );

    // ── Arms (animated) ──
    final armSwing1 = sin(runCycle * pi / 2) * 6;
    canvas.drawLine(
      Offset(cx - 8, p.y + 22),
      Offset(cx - 14 + armSwing1, p.y + 34),
      Paint()..color = jacketColor..strokeWidth = 4..strokeCap = StrokeCap.round,
    );
  }

  void _drawPlayerJumping(Canvas canvas, Player p, bool isDark) {
    final skinColor = isDark ? const Color(0xFFD7CCC8) : const Color(0xFFFFE0B2);
    final jacketColor = isDark ? const Color(0xFF1B5E20) : const Color(0xFFE65100);
    final pantsColor = isDark ? const Color(0xFF263238) : const Color(0xFF37474F);
    final carrierColor = isDark ? const Color(0xFF4A148C) : const Color(0xFF1565C0);
    final bootColor = isDark ? const Color(0xFF3E2723) : const Color(0xFF4E342E);
    final hatColor = isDark ? const Color(0xFF827717) : const Color(0xFFF57F17);

    final cx = p.x + p.width / 2;

    // ── Carrier ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 6, p.y + 16, 18, 28),
        const Radius.circular(4),
      ),
      Paint()..color = carrierColor,
    );

    // ── Body ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 10, p.y + 18, 16, 22),
        const Radius.circular(3),
      ),
      Paint()..color = jacketColor,
    );

    // ── Head ──
    canvas.drawCircle(Offset(cx - 2, p.y + 12), 10, Paint()..color = skinColor);

    // ── Hat ──
    final hatPath = Path();
    hatPath.moveTo(cx - 12, p.y + 10);
    hatPath.lineTo(cx - 2, p.y - 2);
    hatPath.lineTo(cx + 8, p.y + 10);
    hatPath.close();
    canvas.drawPath(hatPath, Paint()..color = hatColor);
    canvas.drawLine(
      Offset(cx - 14, p.y + 10),
      Offset(cx + 10, p.y + 10),
      Paint()..color = hatColor..strokeWidth = 3..strokeCap = StrokeCap.round,
    );

    // Eyes
    canvas.drawCircle(Offset(cx - 5, p.y + 11), 1.5, Paint()..color = Colors.black);

    // ── Legs tucked ──
    canvas.drawLine(
      Offset(cx - 6, p.y + 40),
      Offset(cx - 10, p.y + 50),
      Paint()..color = pantsColor..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx - 10, p.y + 52), 4, Paint()..color = bootColor);

    canvas.drawLine(
      Offset(cx - 2, p.y + 40),
      Offset(cx + 2, p.y + 50),
      Paint()..color = pantsColor..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx + 2, p.y + 52), 4, Paint()..color = bootColor);

    // ── Arms raised ──
    canvas.drawLine(
      Offset(cx - 8, p.y + 22),
      Offset(cx - 16, p.y + 16),
      Paint()..color = jacketColor..strokeWidth = 4..strokeCap = StrokeCap.round,
    );

    // ── Double Jump Wind Burst Effect ──
    if (p.isDoubleJumping && p.doubleJumpEffectTime > 0) {
      final alpha = (p.doubleJumpEffectTime / 0.35).clamp(0.0, 1.0);
      final windPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      final arcPath = Path();
      arcPath.moveTo(cx - 18, p.y + 56);
      arcPath.quadraticBezierTo(cx - 10, p.y + 64, cx - 4, p.y + 58);
      arcPath.moveTo(cx + 4, p.y + 58);
      arcPath.quadraticBezierTo(cx + 10, p.y + 64, cx + 18, p.y + 56);
      canvas.drawPath(arcPath, windPaint);

      final particlePaint = Paint()
        ..color = const Color(0xFF64B5F6).withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - 8, p.y + 63), 2.5, particlePaint);
      canvas.drawCircle(Offset(cx + 8, p.y + 63), 2.5, particlePaint);
    }
  }

  void _drawPlayerDucking(Canvas canvas, Player p, bool isDark) {
    final skinColor = isDark ? const Color(0xFFD7CCC8) : const Color(0xFFFFE0B2);
    final jacketColor = isDark ? const Color(0xFF1B5E20) : const Color(0xFFE65100);
    final pantsColor = isDark ? const Color(0xFF263238) : const Color(0xFF37474F);
    final carrierColor = isDark ? const Color(0xFF4A148C) : const Color(0xFF1565C0);
    final bootColor = isDark ? const Color(0xFF3E2723) : const Color(0xFF4E342E);
    final hatColor = isDark ? const Color(0xFF827717) : const Color(0xFFF57F17);

    final cx = p.x + p.width / 2;
    final duckY = p.y + (GameConstants.playerHeight - GameConstants.playerDuckHeight);

    // ── Carrier (horizontal on back) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 4, duckY + 2, 20, 16),
        const Radius.circular(3),
      ),
      Paint()..color = carrierColor,
    );

    // ── Body (crouched) ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 12, duckY + 8, 18, 14),
        const Radius.circular(3),
      ),
      Paint()..color = jacketColor,
    );

    // ── Head (lowered) ──
    canvas.drawCircle(Offset(cx - 6, duckY + 8), 8, Paint()..color = skinColor);

    // ── Hat ──
    canvas.drawLine(
      Offset(cx - 16, duckY + 6),
      Offset(cx + 4, duckY + 6),
      Paint()..color = hatColor..strokeWidth = 4..strokeCap = StrokeCap.round,
    );

    // Eyes
    canvas.drawCircle(Offset(cx - 9, duckY + 7), 1.5, Paint()..color = Colors.black);

    // ── Legs crouched ──
    canvas.drawLine(
      Offset(cx - 6, duckY + 22),
      Offset(cx - 12, duckY + 30),
      Paint()..color = pantsColor..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx - 12, duckY + 32), 3.5, Paint()..color = bootColor);

    canvas.drawLine(
      Offset(cx, duckY + 22),
      Offset(cx + 6, duckY + 30),
      Paint()..color = pantsColor..strokeWidth = 5..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx + 6, duckY + 32), 3.5, Paint()..color = bootColor);
  }

  void _drawPlayerDead(Canvas canvas, Player p, bool isDark) {
    final skinColor = isDark ? const Color(0xFFD7CCC8) : const Color(0xFFFFE0B2);
    final jacketColor = isDark ? const Color(0xFF1B5E20) : const Color(0xFFE65100);
    final carrierColor = isDark ? const Color(0xFF4A148C) : const Color(0xFF1565C0);
    final hatColor = isDark ? const Color(0xFF827717) : const Color(0xFFF57F17);

    final cx = p.x + p.width / 2;

    // Fallen character
    // Body on ground
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 16, p.y + p.height - 18, 28, 14),
        const Radius.circular(3),
      ),
      Paint()..color = jacketColor.withValues(alpha: 0.8),
    );

    // Head
    canvas.drawCircle(
      Offset(cx - 20, p.y + p.height - 12),
      8,
      Paint()..color = skinColor,
    );

    // X eyes
    final eyePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - 23, p.y + p.height - 14),
      Offset(cx - 19, p.y + p.height - 10),
      eyePaint,
    );
    canvas.drawLine(
      Offset(cx - 19, p.y + p.height - 14),
      Offset(cx - 23, p.y + p.height - 10),
      eyePaint,
    );

    // Hat fallen off
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - 30, p.y + p.height - 4),
        width: 16,
        height: 6,
      ),
      Paint()..color = hatColor,
    );

    // Carrier fallen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + 5, p.y + p.height - 16, 16, 12),
        const Radius.circular(3),
      ),
      Paint()..color = carrierColor.withValues(alpha: 0.7),
    );

    // Stars above head (dizzy effect)
    final starPaint = Paint()..color = const Color(0xFFFFD600);
    for (int i = 0; i < 3; i++) {
      final angle = i * pi * 2 / 3 + engine.mdpl * 0.1;
      final sx = cx - 20 + cos(angle) * 14;
      final sy = p.y + p.height - 26 + sin(angle) * 6;
      _drawStarShape(canvas, sx, sy, 3, starPaint);
    }
  }

  void _drawStarShape(Canvas canvas, double cx, double cy, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + i * 4 * pi / 5;
      final point = Offset(cx + radius * cos(angle), cy + radius * sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // ── Ready Screen Overlay ──
  void _drawReadyOverlay(Canvas canvas, Size size) {
    // Semi-transparent overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // "Tap to Start" text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TAP UNTUK MULAI MENDAKI',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.44),
    );

    // Controls Guide hint
    final hintPainter = TextPainter(
      text: TextSpan(
        text: 'Tap 1x: Lompat  •  Tap 2x: Lompat Jauh  •  Geser: Tunduk',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    hintPainter.layout();
    hintPainter.paint(
      canvas,
      Offset((size.width - hintPainter.width) / 2, size.height * 0.44 + 28),
    );

    // Mountain icon hint
    final mountainIcon = Path();
    final iconCx = size.width / 2;
    final iconCy = size.height * 0.35;
    mountainIcon.moveTo(iconCx - 30, iconCy + 15);
    mountainIcon.lineTo(iconCx - 10, iconCy - 15);
    mountainIcon.lineTo(iconCx, iconCy - 5);
    mountainIcon.lineTo(iconCx + 10, iconCy - 20);
    mountainIcon.lineTo(iconCx + 30, iconCy + 15);
    mountainIcon.close();
    canvas.drawPath(
      mountainIcon,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  // ── Game Over Screen Overlay (Hanya menampilkan rekor baru / skor dan tombol ulang) ──
  void _drawGameOverOverlay(Canvas canvas, Size size) {
    // Semi-transparent dark overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    final bool isNewRecord = engine.mdpl >= engine.highScore && engine.mdpl > 0;

    // Title / Rekor Baru Badge
    final titlePainter = TextPainter(
      text: TextSpan(
        text: isNewRecord ? '🏆 REKOR BARU TERCAPAI!' : 'TERJATUH DI JALUR',
        style: TextStyle(
          color: isNewRecord ? const Color(0xFFFFD54F) : const Color(0xFFEF5350),
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset((size.width - titlePainter.width) / 2, size.height * 0.36),
    );

    // Ketinggian Dicapai (Score Text)
    final scorePainter = TextPainter(
      text: TextSpan(
        text: '${engine.mdpl.toInt()} MDPL',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(
      canvas,
      Offset((size.width - scorePainter.width) / 2, size.height * 0.43),
    );

    // Rekor Terbaik Text
    final bestPainter = TextPainter(
      text: TextSpan(
        text: 'Rekor Terbaik: ${engine.highScore.toInt()} MDPL',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    bestPainter.layout();
    bestPainter.paint(
      canvas,
      Offset((size.width - bestPainter.width) / 2, size.height * 0.51),
    );

    // Tombol Ulang Hint
    final restartPainter = TextPainter(
      text: const TextSpan(
        text: 'TAP UNTUK MAIN LAGI ↺',
        style: TextStyle(
          color: Color(0xFFFF9800),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    restartPainter.layout();
    restartPainter.paint(
      canvas,
      Offset((size.width - restartPainter.width) / 2, size.height * 0.58),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// CustomPainter for rendering animated 6-frame sprite sheets
class SpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int frameIndex;
  final int totalFrames;

  SpritePainter({
    required this.spriteSheet,
    required this.frameIndex,
    this.totalFrames = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = spriteSheet.width / totalFrames;
    final frameHeight = spriteSheet.height.toDouble();

    // Source rect for the specific frame in the spritesheet
    final srcRect = Rect.fromLTWH(
      frameIndex * frameWidth,
      0,
      frameWidth,
      frameHeight,
    );

    // Maintain aspect ratio aligned to bottom center so the character
    // stays proportional and feet always touch the ground
    final frameAspect = frameWidth / frameHeight;
    final targetAspect = size.width / size.height;
    Rect dstRect;

    if (frameAspect < targetAspect) {
      // Fit to height, center horizontally
      final drawWidth = size.height * frameAspect;
      dstRect = Rect.fromLTWH(
        (size.width - drawWidth) / 2,
        0,
        drawWidth,
        size.height,
      );
    } else {
      // Fit to width, align to bottom
      final drawHeight = size.width / frameAspect;
      dstRect = Rect.fromLTWH(
        0,
        size.height - drawHeight,
        size.width,
        drawHeight,
      );
    }

    final paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(spriteSheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant SpritePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex ||
        oldDelegate.spriteSheet != spriteSheet ||
        oldDelegate.totalFrames != totalFrames;
  }
}
