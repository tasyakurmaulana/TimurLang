// ============================================
// TimurLang - Mountain Climber Game Screen
// Visual Game Theme:
// - Background Sky: assets/images/background_sky.png
// - Background Mountain: assets/images/background_mount.png
// - Background Trees: assets/images/background_tree.png
// - Land: assets/images/land.png
// - Hiker: assets/images/hiker 1.png (6-frame sprite sheet)
// - Obstacle 1 (Ground): assets/images/fox.png (4-frame sprite sheet)
// - Obstacle 2 (Air): assets/images/elang.png / eagle.png (4-frame sprite sheet)
// ============================================

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';

/// Jenis variasi rintangan dalam game
enum ObstacleKind {
  rubah,
  kayu,
  elang,
}

/// Representasi rintangan game (Rubah di tanah, Kayu menggelinding di tanah, atau Elang di udara)
class GameObstacle {
  ObstacleKind kind;
  double x;
  double rotation; // Rotasi sudut (radian) untuk animasi kayu menggelinding

  GameObstacle({
    required this.kind,
    required this.x,
    this.rotation = 0.0,
  });

  bool get isEagle => kind == ObstacleKind.elang;
  bool get isFox => kind == ObstacleKind.rubah;
  bool get isWood => kind == ObstacleKind.kayu;
}

/// Entry screen alias for TimurLang app routing
class MountainClimberScreen extends StatelessWidget {
  const MountainClimberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GameScreen();
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final FocusNode _focusNode = FocusNode();

  // ── Asset Images ──
  ui.Image? skyImage;
  ui.Image? mountImage;
  ui.Image? treeImage;
  ui.Image? landImage;
  ui.Image? hikerSpriteSheet;
  ui.Image? foxSpriteSheet;
  ui.Image? eagleSpriteSheet;
  ui.Image? woodImage;
  bool isAssetsLoaded = false;

  // ── Animasi Karakter & Rintangan ──
  int currentRunFrame = 0; // Frame 0..3 untuk lari (4-frame stride cycle hiker 1.png)
  double animTimer = 0;

  int currentFoxFrame = 0; // Frame 0, 1, 2, 3 untuk rubah lari
  double foxAnimTimer = 0;

  int currentEagleFrame = 0; // Frame 0, 1, 2, 3 untuk kepakan sayap elang
  double eagleAnimTimer = 0;

  // ── Fisika Karakter Hiker ──
  double playerY = 0; // 0 = di tanah, negatif = di udara
  double velocityY = 0;
  final double gravity = 1500;
  final double baseHikerHeight = 92.0; // Tinggi berdiri ideal & proporsional
  bool isDucking = false;

  // ── Parallax & Scroll Offset ──
  double scrollOffset = 0;
  double gameSpeed = 270;
  double _bonusSpeedTimer = 0;

  // ── Ukuran Rintangan ──
  final double foxWidth = 84.6;
  final double foxHeight = 44.0;
  final double woodWidth = 46.0;
  final double woodHeight = 46.0;
  final double eagleWidth = 68.0;
  final double eagleHeight = 48.0;
  // Ketinggian elang dari tanah: berdiri pasti kena (92 > 68), menunduk aman lewat di bawah (61.3 < 68)
  final double eagleAltitude = 68.0;

  // ── Daftar Rintangan Berurutan (Dijamin Tidak Pernah Sejajar) ──
  List<GameObstacle> _obstacles = [];

  // ── Kontrol Tap 2x / Double Jump ──
  int _jumpCount = 0; // 0 = di tanah, 1 = lompat biasa, 2 = lompatan kedua (tap 2x)
  DateTime? _lastTapTime;

  // ── Game State & Skor ──
  bool isPlaying = false;
  bool isGameOver = false;
  double mdplScore = 1200;
  double highScore = 1200;
  double _runStartingHighScore = 1200;
  bool _achievedNewRecord = false;
  Duration? _lastTime;

  @override
  void initState() {
    super.initState();
    _loadAllAssets();
    _loadHighScore();
    _ticker = createTicker(_updateGame);
  }

  Future<ui.Image?> _loadUiImage(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('ℹ️ Info loading $assetPath: $e');
      return null;
    }
  }

  Future<void> _loadAllAssets() async {
    // Muat semua asset pada resolusi native untuk pemotongan koordinat yang presisi
    hikerSpriteSheet = await _loadUiImage('assets/images/hiker 1.png') ??
        await _loadUiImage('assets/images/hiker_1.png') ??
        await _loadUiImage('lib/assets/images/hiker 1.png') ??
        await _loadUiImage('lib/assets/images/hiker_1.png') ??
        await _loadUiImage('assets/images/hiker.png') ??
        await _loadUiImage('lib/assets/images/hiker.png') ??
        await _loadUiImage('assets/images/hiker.jpeg');

    skyImage = await _loadUiImage('assets/images/background_sky.png');
    mountImage = await _loadUiImage('assets/images/background_mount.png');
    treeImage = await _loadUiImage('assets/images/background_tree.png');
    landImage = await _loadUiImage('assets/images/land.png');
    foxSpriteSheet = await _loadUiImage('assets/images/fox.png');
    eagleSpriteSheet = await _loadUiImage('assets/images/elang.png') ??
        await _loadUiImage('assets/images/eagle.png');
    woodImage = await _loadUiImage('assets/images/kayu.png');

    if (mounted) {
      setState(() {
        isAssetsLoaded = true;
      });
    }
  }

  Future<void> _loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('mountain_climber_high_score');
      if (saved != null && mounted) {
        setState(() {
          highScore = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('mountain_climber_high_score', highScore);
    } catch (_) {}
  }

  void _startGame() {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      playerY = 0;
      velocityY = 0;
      _jumpCount = 0;
      _lastTapTime = null;
      _bonusSpeedTimer = 0;
      // Inisialisasi rintangan berurutan dengan jarak aman minimal 470px (tidak mungkin sejajar!)
      _obstacles = [
        GameObstacle(kind: ObstacleKind.rubah, x: screenWidth + 180),
        GameObstacle(kind: ObstacleKind.kayu, x: screenWidth + 180 + 470),
        GameObstacle(kind: ObstacleKind.elang, x: screenWidth + 180 + 940),
      ];
      gameSpeed = 270;
      mdplScore = 1200;
      isGameOver = false;
      isPlaying = true;
      _runStartingHighScore = highScore;
      _achievedNewRecord = false;
      isDucking = false;
      currentRunFrame = 0;
      animTimer = 0;
      currentFoxFrame = 0;
      foxAnimTimer = 0;
      currentEagleFrame = 0;
      eagleAnimTimer = 0;
      _lastTime = null;
    });
    HapticFeedback.lightImpact();
    _ticker.start();
  }

  void _jump() {
    if (!isPlaying) {
      _startGame();
      return;
    }
    if (isDucking) return;

    final now = DateTime.now();
    final bool isQuickDoubleTap = _lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 350;
    _lastTapTime = now;

    if (playerY == 0) {
      if (isQuickDoubleTap) {
        // Tap 2x cepat langsung dari tanah: Super jump tinggi & jauh (setinggi elang)
        _jumpCount = 2;
        const double superPeak = 120.0;
        velocityY = -sqrt(2 * gravity * superPeak);
        _bonusSpeedTimer = 0.70;
        HapticFeedback.heavyImpact();
      } else {
        // Tap 1x biasa: Melompati rubah (tinggi 44) dengan nyaman
        _jumpCount = 1;
        const double normalJumpHeight = 68.0;
        velocityY = -sqrt(2 * gravity * normalJumpHeight);
        HapticFeedback.lightImpact();
      }
    } else if (_jumpCount < 2) {
      // Tap ke-2 di udara (Double Jump): Boost mencapai ketinggian elang & meluncur lebih jauh
      _jumpCount = 2;
      const double superPeak = 120.0;
      final double currentAltitude = -playerY;
      final double remainingHeight = max(20.0, superPeak - currentAltitude);
      velocityY = -sqrt(2 * gravity * remainingHeight);
      _bonusSpeedTimer = 0.65;
      HapticFeedback.mediumImpact();
    }
  }

  void _duck(bool status) {
    if (!isPlaying) return;
    if (status) {
      if (playerY == 0 && !isDucking) {
        setState(() => isDucking = true);
        HapticFeedback.selectionClick();

        // Auto stand up setelah 0.7 detik jika tombol tidak dilepas
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted && isDucking) {
            setState(() => isDucking = false);
          }
        });
      }
    } else {
      if (isDucking) {
        setState(() => isDucking = false);
      }
    }
  }

  void _updateGame(Duration elapsed) {
    if (_lastTime == null) {
      _lastTime = elapsed;
      return;
    }
    final double dt = ((elapsed - _lastTime!).inMicroseconds / 1000000.0).clamp(0.0, 0.05);
    _lastTime = elapsed;

    final screenWidth = MediaQuery.of(context).size.width;

    setState(() {
      // 0. Kecepatan Game Efektif (termasuk bonus kecepatan saat lompat jauh)
      double effectiveGameSpeed = gameSpeed;
      if (_bonusSpeedTimer > 0) {
        _bonusSpeedTimer -= dt;
        effectiveGameSpeed += 110.0;
      }

      // 1. Update Fisika Lompat Hiker
      velocityY += gravity * dt;
      playerY += velocityY * dt;
      if (playerY >= 0) {
        playerY = 0;
        velocityY = 0;
        _jumpCount = 0;
      }

      // 2. Update Animasi Lari Hiker (Siklus 4-frame dinamis: Frame 0..3)
      if (playerY == 0 && !isDucking) {
        animTimer += dt;
        final double frameDuration = (0.09 * (300.0 / effectiveGameSpeed)).clamp(0.055, 0.10);
        if (animTimer >= frameDuration) {
          animTimer = 0;
          currentRunFrame = (currentRunFrame + 1) % 4;
        }
      }

      // 3. Update Animasi Lari Rubah (Frame 0, 1, 2, 3)
      foxAnimTimer += dt;
      if (foxAnimTimer >= 0.08) {
        foxAnimTimer = 0;
        currentFoxFrame = (currentFoxFrame + 1) % 4;
      }

      // 4. Update Animasi Kepakan Sayap Elang (Frame 0, 1, 2, 3)
      eagleAnimTimer += dt;
      if (eagleAnimTimer >= 0.10) {
        eagleAnimTimer = 0;
        currentEagleFrame = (currentEagleFrame + 1) % 4;
      }

      // 5. Update Parallax & Jarak Tempuh
      scrollOffset += effectiveGameSpeed * dt;

      // 6. Update Pergerakan Rintangan (Sama Kecepatan: DIJAMIN tidak pernah sejajar)
      for (final obs in _obstacles) {
        obs.x -= effectiveGameSpeed * dt;
        if (obs.isWood) {
          // Menggelinding ke kiri secara fisik tanpa slip: dTheta = dx / R (counter-clockwise)
          obs.rotation -= (effectiveGameSpeed * dt) / (woodWidth / 2.0);
          if (obs.rotation < -2 * pi) {
            obs.rotation += 2 * pi;
          }
        }
      }

      // 7. Respawn Rintangan yang Sudah Lewat Layar Kiri
      for (int i = 0; i < _obstacles.length; i++) {
        final obs = _obstacles[i];
        final double obsWidth = obs.isEagle
            ? eagleWidth
            : (obs.isWood ? woodWidth : foxWidth);
        if (obs.x < -obsWidth - 60) {
          double maxX = screenWidth;
          for (final other in _obstacles) {
            if (other != obs && other.x > maxX) {
              maxX = other.x;
            }
          }
          // Posisi baru selalu di belakang obstacle terjauh dengan jarak minimal 460px
          obs.x = maxX + 460.0 + Random().nextInt(140);
          obs.rotation = 0.0;
          // Ganti variasi rintangan secara acak (Rubah, Kayu Menggelinding, Elang)
          final otherKinds = ObstacleKind.values.where((k) => k != obs.kind).toList();
          obs.kind = otherKinds[Random().nextInt(otherKinds.length)];
          gameSpeed = (gameSpeed + 3).clamp(270.0, 680.0);
        }
      }

      // 8. Skor MDPL
      mdplScore += 14 * dt;
      if (mdplScore > highScore) {
        highScore = mdplScore;
        if (highScore > _runStartingHighScore && highScore > 1200) {
          _achievedNewRecord = true;
        }
      }

      // 9. Deteksi Tabrakan Presisi Menggunakan Model Ketinggian (Altitude Model)
      // Altitude dihitung dari permukaan tanah ke atas (Ground = 0.0)
      const double playerLeft = 65.0;
      final double standingHikerWidth = baseHikerHeight * 0.70; // ~64.4 (proporsional hiker 1.png)
      final double playerXStart = playerLeft + 12.0;
      final double playerXEnd = playerLeft + standingHikerWidth - 12.0;

      final double jumpAltitude = -playerY; // >= 0
      final double currentHeight = isDucking
          ? baseHikerHeight * 0.654 // ~60.2 saat nunduk (aman lewat di bawah elang)
          : baseHikerHeight; // 92.0 saat berdiri

      final double playerAltBottom = jumpAltitude;
      final double playerAltTop = jumpAltitude + currentHeight;

      bool hasCollision = false;
      for (final obs in _obstacles) {
        if (obs.isEagle) {
          // Elang di udara: Altitude [eagleAltitude + 8, eagleAltitude + eagleHeight - 8] -> [76, 108]
          final double eagleXStart = obs.x + 14.0;
          final double eagleXEnd = obs.x + eagleWidth - 14.0;
          final double eagleAltBottom = eagleAltitude + 8.0;
          final double eagleAltTop = eagleAltitude + eagleHeight - 8.0;

          final bool overlapX = playerXEnd > eagleXStart && playerXStart < eagleXEnd;
          final bool overlapAlt = playerAltTop > eagleAltBottom && playerAltBottom < eagleAltTop;

          if (overlapX && overlapAlt) {
            hasCollision = true;
            break;
          }
        } else if (obs.isWood) {
          // Kayu menggelinding di tanah: Altitude [0, woodHeight - 6] -> [0, 40]
          final double woodXStart = obs.x + 8.0;
          final double woodXEnd = obs.x + woodWidth - 8.0;
          const double woodAltBottom = 0.0;
          final double woodAltTop = woodHeight - 6.0;

          final bool overlapX = playerXEnd > woodXStart && playerXStart < woodXEnd;
          final bool overlapAlt = playerAltTop > woodAltBottom && playerAltBottom < woodAltTop;

          if (overlapX && overlapAlt) {
            hasCollision = true;
            break;
          }
        } else {
          // Rubah di tanah: Altitude [0, foxHeight - 10] -> [0, 34]
          final double foxXStart = obs.x + 18.0;
          final double foxXEnd = obs.x + foxWidth - 18.0;
          const double foxAltBottom = 0.0;
          final double foxAltTop = foxHeight - 10.0; // 34.0

          final bool overlapX = playerXEnd > foxXStart && playerXStart < foxXEnd;
          final bool overlapAlt = playerAltTop > foxAltBottom && playerAltBottom < foxAltTop;

          if (overlapX && overlapAlt) {
            hasCollision = true;
            break;
          }
        }
      }

      if (hasCollision) {
        isGameOver = true;
        isPlaying = false;
        if (mdplScore > _runStartingHighScore && mdplScore > 1200) {
          _achievedNewRecord = true;
        }
        _saveHighScore();
        HapticFeedback.heavyImpact();
        _ticker.stop();
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    // Permukaan tanah (land grass) tepat di 72% tinggi layar
    final double groundLevel = screenSize.height * 0.72;

    // Dimensi Hiker sesuai status (Run, Jump, Duck)
    final double standingHikerWidth = baseHikerHeight * 0.70; // ~64.4 (proporsional hiker 1.png)
    final double currentHikerWidth = isDucking
        ? baseHikerHeight * 0.65 // ~59.8 saat merunduk
        : standingHikerWidth;
    final double currentHikerHeight = isDucking
        ? baseHikerHeight * 0.654 // ~60.2 (merunduk lewat di bawah elang)
        : (playerY < 0
            ? baseHikerHeight * 1.108 // ~101.9 (melompat tekuk kaki)
            : baseHikerHeight); // 92.0 (berlari)

    final int activeHikerFrame = isDucking
        ? 5
        : (playerY < 0 ? 4 : (isPlaying ? currentRunFrame : 0));

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.keyS) {
            _duck(true);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.keyW) {
            _jump();
            return KeyEventResult.handled;
          }
        } else if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.keyS) {
            _duck(false);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _jump,
        onVerticalDragStart: (details) {
          if (details.localPosition.dy > 0) {
            _duck(true);
          }
        },
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 3) {
            _duck(true);
          } else if (details.delta.dy < -3) {
            _duck(false);
            _jump();
          }
        },
        onVerticalDragEnd: (_) => _duck(false),
        child: Scaffold(
          backgroundColor: const Color(0xFF64B5F6),
          body: Stack(
            children: [
              // 1. BACKGROUND PARALLAX: SKY, MOUNTAIN, TREE, LAND (DENGAN SUASANA BERGANTI SETIAP 1000 MDPL)
              Positioned.fill(
                child: CustomPaint(
                  painter: MountainParallaxBgPainter(
                    scrollOffset: scrollOffset,
                    groundLevel: groundLevel,
                    mdpl: mdplScore,
                    skyImage: skyImage,
                    mountImage: mountImage,
                    treeImage: treeImage,
                    landImage: landImage,
                  ),
                ),
              ),

              // 2 & 3. RINTANGAN (RUBAH, KAYU MENGGELINDING, & ELANG - 100% NAPAK TANAH & DIJAMIN TIDAK PERNAH SEJAJAR)
              ..._obstacles.map((obs) {
                if (obs.isEagle) {
                  return Positioned(
                    bottom: (screenSize.height - groundLevel) + eagleAltitude,
                    left: obs.x,
                    child: SizedBox(
                      width: eagleWidth,
                      height: eagleHeight,
                      child: eagleSpriteSheet != null
                          ? CustomPaint(
                              painter: EagleSpritePainter(
                                spriteSheet: eagleSpriteSheet!,
                                frameIndex: currentEagleFrame,
                              ),
                            )
                          : CustomPaint(
                              painter: CartoonEagleFallbackPainter(wingFlap: eagleAnimTimer * 8),
                            ),
                    ),
                  );
                } else if (obs.isWood) {
                  return Positioned(
                    bottom: screenSize.height - groundLevel,
                    left: obs.x,
                    child: SizedBox(
                      width: woodWidth,
                      height: woodHeight,
                      child: woodImage != null
                          ? CustomPaint(
                              painter: RollingWoodPainter(
                                woodImage: woodImage!,
                                rotation: obs.rotation,
                              ),
                            )
                          : CustomPaint(
                              painter: CartoonRollingWoodPainter(rotation: obs.rotation),
                            ),
                    ),
                  );
                } else {
                  return Positioned(
                    bottom: screenSize.height - groundLevel,
                    left: obs.x,
                    child: SizedBox(
                      width: foxWidth,
                      height: foxHeight,
                      child: foxSpriteSheet != null
                          ? CustomPaint(
                              painter: FoxSpritePainter(
                                spriteSheet: foxSpriteSheet!,
                                frameIndex: currentFoxFrame,
                              ),
                            )
                          : CustomPaint(
                              painter: CartoonPineTreePainter(),
                            ),
                    ),
                  );
                }
              }),

              // 4. KARAKTER PENDAKI / HIKER (100% NAPAK TANAH DENGAN KAKI MENEMPEL DI RUMPUT)
              Positioned(
                bottom: (screenSize.height - groundLevel) - playerY,
                left: 65,
                child: SizedBox(
                  width: currentHikerWidth,
                  height: currentHikerHeight,
                  child: hikerSpriteSheet == null
                      ? const SizedBox()
                      : CustomPaint(
                          painter: HikerSpritePainter(
                            spriteSheet: hikerSpriteSheet!,
                            frameIndex: activeHikerFrame,
                          ),
                        ),
                ),
              ),

              // 4.5 ON-SCREEN HUD CONTROLS (TOMBOL LOMPAT & MERUNDUK KHUSUS LAYAR SENTUH)
              if (isPlaying && !isGameOver)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Tombol Nunduk / Slide
                      GestureDetector(
                        onTapDown: (_) => _duck(true),
                        onTapUp: (_) => _duck(false),
                        onTapCancel: () => _duck(false),
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: isDucking
                                ? AppTheme.primary
                                : AppTheme.surface.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDucking ? AppTheme.primaryHover : AppTheme.border,
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.textPrimary.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.keyboard_double_arrow_down_rounded,
                            color: isDucking ? Colors.white : AppTheme.textPrimary,
                            size: 30,
                          ),
                        ),
                      ),

                      // Tombol Lompat / Jump
                      GestureDetector(
                        onTap: _jump,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.secondary],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 5. TOP BAR: TOMBOL KEMBALI & PANEL SKOR MDPL (Aura Travel Design System)
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Tombol Kembali
                    GestureDetector(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.textPrimary.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
                      ),
                    ),
                    const Spacer(),

                    // High Score Card
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textPrimary.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: AppTheme.warning, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'BEST: ${highScore.toInt()} M',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Skor MDPL Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.secondary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.terrain_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${mdplScore.toInt()} MDPL',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 6. LAYAR MULAI / GAME OVER (Aura Travel Design System Card)
              if (!isPlaying)
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    constraints: const BoxConstraints(maxWidth: 380),
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon Badge
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: isGameOver
                                      ? (_achievedNewRecord
                                          ? const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFF59E0B)])
                                          : const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]))
                                      : const LinearGradient(colors: [AppTheme.primary, AppTheme.secondary]),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isGameOver
                                              ? (_achievedNewRecord ? AppTheme.warning : AppTheme.error)
                                              : AppTheme.primary)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isGameOver
                                      ? (_achievedNewRecord ? Icons.emoji_events_rounded : Icons.heart_broken_rounded)
                                      : Icons.terrain_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Judul
                              Text(
                                isGameOver
                                    ? (_achievedNewRecord ? '🏆 REKOR BARU TERCAPAI!' : 'TERJATUH DI JALUR')
                                    : 'MINIGAMES PENDAKI',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Subtitle
                              Text(
                                isGameOver
                                    ? (_achievedNewRecord
                                        ? 'Luar biasa! Kamu menembus rekor pendakian tertinggi baru!'
                                        : 'Ketinggian: ${mdplScore.toInt()} MDPL • Rekor: ${highScore.toInt()} MDPL')
                                    : 'Hindari rintangan rubah, kayu menggelinding, dan elang, daki gunung setinggi mungkin!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // KONDISI 1: Saat Game Over -> Muncul Rekor Baru / Skor dan Tombol Ulang
                              if (isGameOver) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _achievedNewRecord
                                          ? AppTheme.warning.withValues(alpha: 0.5)
                                          : AppTheme.border,
                                      width: _achievedNewRecord ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      if (_achievedNewRecord) ...[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.stars_rounded, color: AppTheme.warning, size: 18),
                                            const SizedBox(width: 6),
                                            Text(
                                              'PENCAPAIAN REKOR TERTINGGI',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: AppTheme.warning,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Ketinggian Dicapai',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${mdplScore.toInt()} MDPL',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Divider(color: AppTheme.border, height: 1),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Rekor Terbaik',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${highScore.toInt()} MDPL',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppTheme.warning,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                              // KONDISI 2: Saat Entrance di Awal -> Tampilkan Controls Guide Hint
                              else ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildControlTip(
                                        icon: '🦊',
                                        action: 'Rubah / Kayu',
                                        instruction: 'Ketuk 1x untuk Melompati Rintangan Tanah',
                                        accentColor: AppTheme.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildControlTip(
                                        icon: '⚡',
                                        action: 'Tap 2x',
                                        instruction: 'Lompat Jauh (Setinggi Elang)',
                                        accentColor: AppTheme.warning,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildControlTip(
                                        icon: '🦅',
                                        action: 'Elang',
                                        instruction: 'Geser Bawah untuk Menunduk',
                                        accentColor: AppTheme.secondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),

                              // Tombol Mulai / Main Lagi
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(isGameOver ? Icons.replay_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        isGameOver ? 'MAIN LAGI' : 'MULAI PENDAKIAN',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlTip({
    required String icon,
    required String action,
    required String instruction,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Text(
          '$action: ',
          style: GoogleFonts.plusJakartaSans(
            color: accentColor,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        Expanded(
          child: Text(
            instruction,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 1. SPRITE PAINTER HIKER (hiker 1.png 6-FRAME SPRITESHEET)
// Frame 0..3 : Siklus Berlari 4-Frame (Stride dinamis & halus)
// Frame 4    : Pose Melompat (Kaki ditekuk melayang di udara, tongkat terangkat)
// Frame 5    : Pose Menunduk / Merunduk (Badan rendah lewat di bawah elang)
// Koordinat persentase presisi: Kaki 100% menempel di dasar (napak tanah)
// ============================================================================
class HikerSpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int frameIndex;

  HikerSpritePainter({
    required this.spriteSheet,
    required this.frameIndex,
  });

  // Mapping koordinat rasio 6-frame presisi untuk 'hiker 1.png' (1355 x 670)
  // [xRel, yRel, wRel, hRel]
  static const List<List<double>> _frameSpecsHiker1 = [
    [33.0 / 1355.0, 230.0 / 670.0, 171.0 / 1355.0, 240.0 / 670.0],   // Frame 0: Stride 1
    [261.0 / 1355.0, 230.0 / 670.0, 167.0 / 1355.0, 240.0 / 670.0],  // Frame 1: Stride 2
    [483.0 / 1355.0, 230.0 / 670.0, 166.0 / 1355.0, 240.0 / 670.0],  // Frame 2: Stride 3
    [705.0 / 1355.0, 230.0 / 670.0, 168.0 / 1355.0, 240.0 / 670.0],  // Frame 3: Stride 4
    [936.0 / 1355.0, 189.0 / 670.0, 168.0 / 1355.0, 266.0 / 670.0],  // Frame 4: Melompat (Jump)
    [1161.0 / 1355.0, 319.0 / 670.0, 154.0 / 1355.0, 157.0 / 670.0], // Frame 5: Menunduk (Duck)
  ];

  // Mapping cadangan jika memuat hiker.png lama (9-frame)
  static const List<List<double>> _frameSpecsOld = [
    [0.2675, 0.4305, 0.5539, 0.3542], // Frame 0
    [0.1286, 0.4305, 0.6928, 0.3550], // Frame 1
    [0.3241, 0.4305, 0.4973, 0.3542], // Frame 2
    [0.2812, 0.4305, 0.5402, 0.3542], // Frame 3
    [0.1286, 0.4305, 0.6928, 0.3550], // Frame 4
    [0.3241, 0.4305, 0.4973, 0.3542], // Frame 5
    [0.3241, 0.4305, 0.4973, 0.3542], // Frame 6
    [0.3979, 0.1930, 0.5231, 0.3908], // Frame 7
    [0.3824, 0.5012, 0.4990, 0.2851], // Frame 8
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double sw = spriteSheet.width.toDouble();
    final double sh = spriteSheet.height.toDouble();
    final bool isHiker1 = (sw / sh) < 3.0; // hiker 1.png rasio ~2.02 vs old hiker ~4.16

    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    if (isHiker1) {
      final int f = frameIndex.clamp(0, _frameSpecsHiker1.length - 1);
      final spec = _frameSpecsHiker1[f];

      final double srcX = spec[0] * sw;
      final double srcY = spec[1] * sh;
      final double srcW = spec[2] * sw;
      final double srcH = spec[3] * sh;
      final Rect srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);

      final double srcAspect = srcW / srcH;
      final double dstHeight = size.height;
      final double dstWidth = dstHeight * srcAspect;

      // Anchor horizontal: Posisi di tengah widget
      final double dstX = (size.width - dstWidth) / 2.0;
      final double dstY = size.height - dstHeight; // Napak tanah
      final Rect dstRect = Rect.fromLTWH(dstX, dstY, dstWidth, dstHeight);

      canvas.drawImageRect(spriteSheet, srcRect, dstRect, paint);
    } else {
      final double fw = sw / 9.0;
      final int f = frameIndex.clamp(0, 8);
      final spec = _frameSpecsOld[f];

      final double srcX = f * fw + (fw * spec[0]);
      final double srcY = sh * spec[1];
      final double srcW = fw * spec[2];
      final double srcH = sh * spec[3];
      final Rect srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);

      final double srcAspect = srcW / srcH;
      final double dstHeight = size.height;
      final double dstWidth = dstHeight * srcAspect;

      final double dstX = f <= 6
          ? (size.width / 2.0) - (((0.5 - spec[0]) / spec[2]) * dstWidth)
          : (size.width - dstWidth) / 2.0;
      const double dstY = 0.0;
      final Rect dstRect = Rect.fromLTWH(dstX, dstY, dstWidth, dstHeight);

      canvas.drawImageRect(spriteSheet, srcRect, dstRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HikerSpritePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex ||
        oldDelegate.spriteSheet != spriteSheet;
  }
}

// ============================================================================
// 2. SPRITE PAINTER RUBAH (fox.png 4-FRAME SPRITESHEET)
// Koordinat persentase presisi: Kaki rubah 100% menempel di rumput (napak tanah)
// ============================================================================
class FoxSpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int frameIndex;

  FoxSpritePainter({
    required this.spriteSheet,
    required this.frameIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double fw = spriteSheet.width / 4.0;
    final double sh = spriteSheet.height.toDouble();
    final int f = frameIndex.clamp(0, 3);

    final double srcX = f * fw + (fw * 0.08);
    final double srcW = fw * 0.88;
    const double srcY = 0.0;
    final double srcH = sh * 0.89;

    final Rect srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);
    final Rect dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(spriteSheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant FoxSpritePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex ||
        oldDelegate.spriteSheet != spriteSheet;
  }
}

// ============================================================================
// 2.5 SPRITE PAINTER KAYU MENGGELINDING (kayu.png)
// Kayu berputar rotasi fisik tanpa slip dan 100% menapak tanah di atas rumput
// ============================================================================
class RollingWoodPainter extends CustomPainter {
  final ui.Image woodImage;
  final double rotation;

  RollingWoodPainter({
    required this.woodImage,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2.0;
    final Offset center = Offset(radius, size.height / 2.0);

    // 1. Bayangan kontak halus di tanah agar benar-benar menapak tanah
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 0.5),
        width: size.width * 0.78,
        height: 4.5,
      ),
      shadowPaint,
    );

    // 2. Gambar kayu menggelinding dengan rotasi berpusat di tengah
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      woodImage.width.toDouble(),
      woodImage.height.toDouble(),
    );
    final Rect dstRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );

    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(woodImage, srcRect, dstRect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RollingWoodPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.woodImage != woodImage;
  }
}

class CartoonRollingWoodPainter extends CustomPainter {
  final double rotation;

  CartoonRollingWoodPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2.0;
    final Offset center = Offset(radius, size.height / 2.0);

    // Bayangan kontak tanah
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 0.5),
        width: size.width * 0.78,
        height: 4.5,
      ),
      shadowPaint,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    // Kulit luar kayu (bark)
    final barkPaint = Paint()..color = const Color(0xFF5D4037);
    canvas.drawCircle(Offset.zero, radius, barkPaint);

    // Kayu dalam
    final woodPaint = Paint()..color = const Color(0xFFD7CCC8);
    canvas.drawCircle(Offset.zero, radius * 0.88, woodPaint);

    // Cincin tahunan pohon
    final ringPaint = Paint()
      ..color = const Color(0xFFBCAAA4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset.zero, radius * 0.60, ringPaint);
    canvas.drawCircle(Offset.zero, radius * 0.32, ringPaint);

    // Retakan kayu (cracks)
    final crackPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(radius * 0.75, 0), crackPaint);
    canvas.drawLine(Offset.zero, Offset(-radius * 0.5, radius * 0.5), crackPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CartoonRollingWoodPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

// ============================================================================
// 3. SPRITE PAINTER BURUNG ELANG (elang.png 4-FRAME SPRITESHEET)
// ============================================================================
class EagleSpritePainter extends CustomPainter {
  final ui.Image spriteSheet;
  final int frameIndex;

  EagleSpritePainter({
    required this.spriteSheet,
    required this.frameIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double fw = spriteSheet.width / 4.0;
    final double sh = spriteSheet.height.toDouble();
    final int f = frameIndex.clamp(0, 3);

    final double srcX = f * fw + (fw * 0.06);
    final double srcW = fw * 0.92;
    final double srcY = sh * 0.16;
    final double srcH = sh * 0.68;

    final Rect srcRect = Rect.fromLTWH(srcX, srcY, srcW, srcH);
    final Rect dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final Paint paint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;

    canvas.drawImageRect(spriteSheet, srcRect, dstRect, paint);
  }

  @override
  bool shouldRepaint(covariant EagleSpritePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex ||
        oldDelegate.spriteSheet != spriteSheet;
  }
}

// ============================================================================
// 4. PARALLAX BACKGROUND PAINTER (SKY, MOUNTAIN, TREE, LAND)
// Memastikan permukaan rumput land.png sejajar 100% dengan groundLevel
// ============================================================================
class MountainParallaxBgPainter extends CustomPainter {
  final double scrollOffset;
  final double groundLevel;
  final double mdpl;
  final ui.Image? skyImage;
  final ui.Image? mountImage;
  final ui.Image? treeImage;
  final ui.Image? landImage;

  MountainParallaxBgPainter({
    required this.scrollOffset,
    required this.groundLevel,
    required this.mdpl,
    this.skyImage,
    this.mountImage,
    this.treeImage,
    this.landImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint imagePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    // A. SUASANA LANGIT (BERGANTI SETIAP KELIPATAN 1000 MDPL)
    // 0 = Pagi (Cerah), 1 = Senja (Sunset Oranye/Lembayung), 2 = Malam (Deep Indigo & Bintang)
    const double skyInterval = 1000.0;
    const double transitionLen = 200.0;
    final int cycle = (mdpl / skyInterval).floor();
    final int phaseIndex = cycle % 3;
    final double progressInInterval = mdpl % skyInterval;
    final double transitionStart = skyInterval - transitionLen;
    final double t = progressInInterval < transitionStart
        ? 0.0
        : ((progressInInterval - transitionStart) / transitionLen).clamp(0.0, 1.0);

    double senjaFactor = 0.0;
    double malamFactor = 0.0;

    if (phaseIndex == 0) {
      // Pagi -> Senja
      senjaFactor = t;
      malamFactor = 0.0;
    } else if (phaseIndex == 1) {
      // Senja -> Malam
      senjaFactor = 1.0 - t;
      malamFactor = t;
    } else {
      // Malam -> Pagi
      senjaFactor = 0.0;
      malamFactor = 1.0 - t;
    }

    if (skyImage != null) {
      // Gambar background_sky dasar
      canvas.drawImageRect(
        skyImage!,
        Rect.fromLTWH(0, 0, skyImage!.width.toDouble(), skyImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        imagePaint,
      );

      // Overlay Suasana Senja (Sunset Glow hangat keemasan & oranye)
      if (senjaFactor > 0.01) {
        final Rect skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
        final Paint senjaPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF311B92).withValues(alpha: 0.42 * senjaFactor), // Lembayung ungu atas
              const Color(0xFFE65100).withValues(alpha: 0.52 * senjaFactor), // Sunset oranye tengah
              const Color(0xFFFFB300).withValues(alpha: 0.38 * senjaFactor), // Cahaya keemasan horizon
            ],
          ).createShader(skyRect);
        canvas.drawRect(skyRect, senjaPaint);
      }

      // Overlay Suasana Malam (Deep Indigo & Bintang-Bintang)
      if (malamFactor > 0.01) {
        final Rect skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
        final Paint malamPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A0C1E).withValues(alpha: 0.78 * malamFactor),
              const Color(0xFF141A35).withValues(alpha: 0.68 * malamFactor),
              const Color(0xFF1F2B4C).withValues(alpha: 0.52 * malamFactor),
            ],
          ).createShader(skyRect);
        canvas.drawRect(skyRect, malamPaint);

        // Bintang-bintang malam
        final starPaint = Paint()..color = Colors.white;
        final double starAlphaBase = (malamFactor * 0.9).clamp(0.0, 1.0);
        for (int i = 0; i < 40; i++) {
          final double sx = ((i * 137.5) % size.width);
          final double sy = ((i * 73.1) % (groundLevel * 0.65));
          final double flicker = 0.5 + 0.5 * sin(scrollOffset * 0.025 + i * 1.7);
          final double starAlpha = (starAlphaBase * flicker).clamp(0.0, 1.0);
          final double starR = 1.0 + (i % 3) * 0.7;
          canvas.drawCircle(Offset(sx, sy), starR, starPaint..color = Colors.white.withValues(alpha: starAlpha));
        }
      }
    } else {
      // Fallback gradient jika skyImage null
      final List<Color> currentColors;
      final List<Color> nextColors;
      switch (phaseIndex) {
        case 0:
          currentColors = const [Color(0xFF29B6F6), Color(0xFFB3E5FC), Color(0xFFFFF9C4)];
          nextColors = const [Color(0xFF1A237E), Color(0xFFE65100), Color(0xFFFFCC02)];
          break;
        case 1:
          currentColors = const [Color(0xFF1A237E), Color(0xFFE65100), Color(0xFFFFCC02)];
          nextColors = const [Color(0xFF0D0D2B), Color(0xFF1A1A3E), Color(0xFF2C2C54)];
          break;
        case 2:
        default:
          currentColors = const [Color(0xFF0D0D2B), Color(0xFF1A1A3E), Color(0xFF2C2C54)];
          nextColors = const [Color(0xFF29B6F6), Color(0xFFB3E5FC), Color(0xFFFFF9C4)];
          break;
      }
      final colors = List.generate(3, (i) => Color.lerp(currentColors[i], nextColors[i], t)!);
      final Rect skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
      final Paint skyPaint = Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(skyRect);
      canvas.drawRect(skyRect, skyPaint);
    }

    // B. PEGUNUNGAN (background_mount.png - Parallax 0.12x)
    if (mountImage != null) {
      final double cleanMountW = mountImage!.width > 5300 ? 5302.0 : mountImage!.width.toDouble();
      final double cleanMountH = mountImage!.height > 1570 ? 1572.0 : mountImage!.height.toDouble();
      final double mountHeight = size.height * 0.50;
      final double mountWidth = cleanMountW * (mountHeight / cleanMountH);
      final double mountY = (groundLevel + 18) - mountHeight;
      final double offsetM = (scrollOffset * 0.12) % mountWidth;

      double mx = -offsetM;
      while (mx < size.width) {
        canvas.drawImageRect(
          mountImage!,
          Rect.fromLTWH(0, 0, cleanMountW, cleanMountH),
          Rect.fromLTWH(mx, mountY, mountWidth, mountHeight),
          imagePaint,
        );
        mx += mountWidth;
      }
    }

    // C. POHON & CAMP SIGN (background_tree.png - Parallax 0.40x)
    if (treeImage != null) {
      final double cleanTreeW = treeImage!.width > 5320 ? 5324.0 : treeImage!.width.toDouble();
      final double cleanTreeH = treeImage!.height > 1130 ? 1138.0 : treeImage!.height.toDouble();
      final double treeHeight = size.height * 0.40;
      final double treeWidth = cleanTreeW * (treeHeight / cleanTreeH);
      // Batang pohon & tiang papan CAMP tertancap sedikit ke dalam rumput (10px)
      final double treeY = (groundLevel + 10) - treeHeight;
      final double offsetT = (scrollOffset * 0.40) % treeWidth;

      double tx = -offsetT;
      while (tx < size.width) {
        canvas.drawImageRect(
          treeImage!,
          Rect.fromLTWH(0, 0, cleanTreeW, cleanTreeH),
          Rect.fromLTWH(tx, treeY, treeWidth, treeHeight),
          imagePaint,
        );
        tx += treeWidth;
      }
    }

    // D. TANAH PIJAKAN (land.png - Kecepatan 1.0x)
    // Pada land.png terbaru (5319x466), permukaan rumput dimulai langsung dari y = 0.
    // landY tepat sejajar di groundLevel, mengisi penuh ke bawah layar tanpa celah.
    if (landImage != null) {
      final double cleanLandW = landImage!.width > 5310 ? 5316.0 : landImage!.width.toDouble();
      final double cleanLandH = landImage!.height > 460 ? 463.0 : landImage!.height.toDouble();
      final double landHeight = (size.height - groundLevel) + 4;
      final double landWidth = cleanLandW * (landHeight / cleanLandH);
      final double landY = groundLevel;
      final double offsetL = (scrollOffset * 1.0) % landWidth;

      double lx = -offsetL;
      while (lx < size.width) {
        canvas.drawImageRect(
          landImage!,
          Rect.fromLTWH(0, 0, cleanLandW, cleanLandH),
          Rect.fromLTWH(lx, landY, landWidth, landHeight),
          imagePaint,
        );
        lx += landWidth;
      }
    } else {
      // Fallback jika asset land belum terload
      canvas.drawRect(
        Rect.fromLTWH(0, groundLevel, size.width, size.height - groundLevel),
        Paint()..color = const Color(0xFFA97142),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, groundLevel, size.width, 22),
        Paint()..color = const Color(0xFF66BB6A),
      );
    }
  }

  @override
  bool shouldRepaint(covariant MountainParallaxBgPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.groundLevel != groundLevel ||
        oldDelegate.mdpl != mdpl ||
        oldDelegate.skyImage != skyImage ||
        oldDelegate.mountImage != mountImage ||
        oldDelegate.treeImage != treeImage ||
        oldDelegate.landImage != landImage;
  }
}

// ============================================================================
// 5. FALLBACK PAINTERS (JIKA ASSET BELUM TERMUAT)
// ============================================================================
class CartoonPineTreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const Color outlineColor = Color(0xFF2B2B2B);
    final Paint outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeJoin = StrokeJoin.round;

    final double cx = size.width / 2;

    // Batang Pohon
    final RRect trunkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 8, size.height * 0.65, 16, size.height * 0.35),
      const Radius.circular(4),
    );
    canvas.drawRRect(trunkRect, Paint()..color = const Color(0xFF8D5B3C));
    canvas.drawRRect(trunkRect, outlinePaint);

    // Daun Pinus
    final Path path = Path()
      ..moveTo(cx, 0)
      ..lineTo(size.width, size.height * 0.7)
      ..lineTo(0, size.height * 0.7)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF43A047));
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CartoonEagleFallbackPainter extends CustomPainter {
  final double wingFlap;

  CartoonEagleFallbackPainter({required this.wingFlap});

  @override
  void paint(Canvas canvas, Size size) {
    const Color outlineColor = Color(0xFF2B2B2B);
    final Paint outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round;

    final double flapOffset = sin(wingFlap) * 8.0;
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Sayap
    final Path wing = Path()
      ..moveTo(cx, cy)
      ..quadraticBezierTo(cx - size.width * 0.45, cy - 14 + flapOffset, cx - size.width * 0.5, cy + 6 + flapOffset)
      ..quadraticBezierTo(cx - size.width * 0.25, cy + 4, cx, cy + 6)
      ..close();
    canvas.drawPath(wing, Paint()..color = const Color(0xFF5D4037));
    canvas.drawPath(wing, outlinePaint);

    // Badan
    final RRect body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 22, height: 26),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFF4E342E));
    canvas.drawRRect(body, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CartoonEagleFallbackPainter oldDelegate) =>
      oldDelegate.wingFlap != wingFlap;
}
