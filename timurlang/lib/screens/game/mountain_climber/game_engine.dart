// ============================================
// TimurLang - Mountain Climber Game Engine
// Core game loop, physics, spawning, collision
// ============================================

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_constants.dart';
import 'game_models.dart';

class GameEngine {
  // ── Game State ──
  GameStatus status = GameStatus.ready;
  double mdpl = 0;
  double highScore = 0;
  double currentSpeed = GameConstants.initialSpeed;
  SkyPhase skyPhase = SkyPhase.pagi;
  double skyTransitionProgress = 0.0; // 0.0 to 1.0 during transitions

  // ── Entities ──
  late Player player;
  final List<Obstacle> obstacles = [];
  late ParallaxLayer farMountains;
  late ParallaxLayer nearMountains;
  late ParallaxLayer trees;
  late ParallaxLayer fog;
  final List<Star> stars = [];

  // ── Internal ──
  final Random _random = Random();
  double _nextObstacleDistance = 0;
  double _distanceSinceLastObstacle = 0;
  double _screenWidth = 0;
  double _screenHeight = 0;
  double _groundY = 0;

  // ── Callbacks ──
  Function()? onGameOver;
  Function(double mdpl)? onScoreUpdate;

  GameEngine() {
    player = Player(x: GameConstants.playerXPosition, y: 0);
    _initParallaxLayers();
    _generateStars();
    _loadHighScore();
  }

  void _initParallaxLayers() {
    farMountains = ParallaxLayer(speedRatio: GameConstants.farMountainSpeedRatio);
    nearMountains = ParallaxLayer(speedRatio: GameConstants.nearMountainSpeedRatio);
    trees = ParallaxLayer(speedRatio: GameConstants.treesSpeedRatio);
    fog = ParallaxLayer(speedRatio: GameConstants.fogSpeedRatio);
  }

  void _generateStars() {
    stars.clear();
    for (int i = 0; i < GameConstants.maxStars; i++) {
      stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble() * 0.5, // upper half of sky
        size: 1.0 + _random.nextDouble() * 2.5,
        twinkleOffset: _random.nextDouble() * pi * 2,
      ));
    }
  }

  Future<void> _loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getDouble('mountain_climber_high_score') ?? 0;
    } catch (_) {
      highScore = 0;
    }
  }

  Future<void> _saveHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('mountain_climber_high_score', highScore);
    } catch (_) {}
  }

  void setScreenSize(double width, double height) {
    if (_screenWidth == width && _screenHeight == height) return;
    _screenWidth = width;
    _screenHeight = height;
    _groundY = height * (1.0 - GameConstants.groundHeightRatio);
    if (player.isOnGround) {
      player.y = _groundY - player.height;
    }
  }

  double get groundY => _groundY;
  double get screenWidth => _screenWidth;
  double get screenHeight => _screenHeight;

  // ── Game Controls ──
  void start() {
    if (status == GameStatus.ready || status == GameStatus.gameOver) {
      _reset();
      status = GameStatus.running;
    }
  }

  ({bool success, bool isDoubleJump}) jump() {
    if (status == GameStatus.ready) {
      start();
      return player.jump();
    } else if (status == GameStatus.running) {
      return player.jump();
    }
    return (success: false, isDoubleJump: false);
  }

  void duck() {
    if (status == GameStatus.running) {
      player.duck();
    }
  }

  void standUp() {
    if (status == GameStatus.running) {
      player.standUp();
    }
  }

  void restart() {
    _reset();
    status = GameStatus.running;
  }

  void _reset() {
    mdpl = 0;
    currentSpeed = GameConstants.initialSpeed;
    skyPhase = SkyPhase.pagi;
    skyTransitionProgress = 0.0;
    obstacles.clear();
    _nextObstacleDistance = GameConstants.minObstacleGap;
    _distanceSinceLastObstacle = 0;
    player.reset(_groundY);
    _initParallaxLayers();
  }

  // ── Main Update Loop ──
  void update(double dt) {
    if (status != GameStatus.running) return;

    // Clamp dt to prevent physics issues
    final clampedDt = dt.clamp(0.0, 0.05);

    // Update MDPL score
    mdpl += GameConstants.mdplPerSecond * (currentSpeed / GameConstants.initialSpeed) * clampedDt;
    onScoreUpdate?.call(mdpl);

    // Increase speed based on MDPL
    currentSpeed = (GameConstants.initialSpeed + mdpl * GameConstants.speedIncreasePerMdpl)
        .clamp(GameConstants.initialSpeed, GameConstants.maxSpeed);

    // Update sky phase
    _updateSkyPhase();

    // Update player
    player.update(clampedDt, _groundY);

    // Update obstacles
    _updateObstacles(clampedDt);

    // Spawn new obstacles
    _spawnObstacles(clampedDt);

    // Update parallax
    farMountains.update(clampedDt, currentSpeed);
    nearMountains.update(clampedDt, currentSpeed);
    trees.update(clampedDt, currentSpeed);
    fog.update(clampedDt, currentSpeed);

    // Update star twinkle
    _updateStars(clampedDt);

    // Check collisions
    _checkCollisions();
  }

  void _updateSkyPhase() {
    // Berganti suasana sky phase setiap kelipatan 1000 MDPL (Pagi -> Senja -> Malam -> Pagi ...)
    final double interval = GameConstants.skyPhaseInterval;
    final double transitionLen = GameConstants.skyTransitionLength;

    final int cycle = (mdpl / interval).floor();
    final int phaseIndex = cycle % 3; // 0 = pagi, 1 = senja, 2 = malam
    final double progressInInterval = mdpl % interval;
    final double transitionStart = interval - transitionLen;

    switch (phaseIndex) {
      case 0:
        skyPhase = SkyPhase.pagi;
        break;
      case 1:
        skyPhase = SkyPhase.senja;
        break;
      case 2:
        skyPhase = SkyPhase.malam;
        break;
    }

    if (progressInInterval < transitionStart) {
      skyTransitionProgress = 0.0;
    } else {
      skyTransitionProgress =
          ((progressInInterval - transitionStart) / transitionLen).clamp(0.0, 1.0);
    }
  }

  /// Tingkat kegelapan lingkungan (0.0 = terang pagi, 1.0 = malam pekat)
  double get darkness {
    final t = skyTransitionProgress;
    switch (skyPhase) {
      case SkyPhase.pagi:
        return 0.30 * t; // 0.0 -> 0.30
      case SkyPhase.senja:
        return 0.30 + (0.70 * t); // 0.30 -> 1.0
      case SkyPhase.malam:
        return 1.0 - (1.0 * t); // 1.0 -> 0.0 (fajar)
    }
  }

  void _updateStars(double dt) {
    for (var star in stars) {
      star.brightness =
          0.5 + 0.5 * sin(star.twinkleOffset + mdpl * GameConstants.starTwinkleSpeed * 0.01);
    }
  }

  void _updateObstacles(double dt) {
    for (var obstacle in obstacles) {
      obstacle.update(dt, currentSpeed);
    }
    obstacles.removeWhere((o) => o.isOffScreen);
  }

  void _spawnObstacles(double dt) {
    _distanceSinceLastObstacle += currentSpeed * dt;

    if (_distanceSinceLastObstacle >= _nextObstacleDistance) {
      _distanceSinceLastObstacle = 0;

      // Determine gap for next obstacle (closer = harder)
      final difficultyFactor = (currentSpeed / GameConstants.maxSpeed).clamp(0.0, 1.0);
      _nextObstacleDistance = GameConstants.maxObstacleGap -
          (GameConstants.maxObstacleGap - GameConstants.minObstacleGap) * difficultyFactor * 0.7 +
          (_random.nextDouble() - 0.5) * 2 * GameConstants.maxObstacleGap * GameConstants.obstacleSpawnVariation;
      _nextObstacleDistance = _nextObstacleDistance.clamp(
        GameConstants.minObstacleGap * 0.8,
        GameConstants.maxObstacleGap,
      );

      // Rintangan atas (elang, dahan) hanya muncul setelah pemain mencapai 250 MDPL
      // agar di awal pemain fokus melompati rintangan bawah
      final canSpawnTop = mdpl >= 250.0;
      final topObstacleChance = canSpawnTop ? (0.20 + difficultyFactor * 0.25) : 0.0;
      final isTopObstacle = _random.nextDouble() < topObstacleChance;

      if (isTopObstacle) {
        _spawnTopObstacle();
      } else {
        _spawnBottomObstacle();
      }
    }
  }

  void _spawnBottomObstacle() {
    final config = GameConstants.bottomObstacles[
        _random.nextInt(GameConstants.bottomObstacles.length)];
    final width = (config['width'] as double) + _random.nextDouble() * 6;
    final height = (config['height'] as double) + _random.nextDouble() * 4;

    obstacles.add(Obstacle(
      x: _screenWidth + 20,
      y: _groundY - height,
      width: width,
      height: height,
      type: ObstacleType.bawah,
      name: config['name'] as String,
    ));
  }

  void _spawnTopObstacle() {
    final config = GameConstants.topObstacles[
        _random.nextInt(GameConstants.topObstacles.length)];
    final width = (config['width'] as double) + _random.nextDouble() * 10;
    final height = (config['height'] as double) + _random.nextDouble() * 8;

    // Position at a height the player must duck to avoid
    final topY = _groundY - GameConstants.playerHeight - height + 14;

    obstacles.add(Obstacle(
      x: _screenWidth + 20,
      y: topY,
      width: width,
      height: height,
      type: ObstacleType.atas,
      name: config['name'] as String,
    ));
  }

  void _checkCollisions() {
    final playerHitbox = player.hitbox;

    for (var obstacle in obstacles) {
      if (playerHitbox.overlaps(obstacle.hitbox)) {
        _triggerGameOver();
        return;
      }
    }
  }

  void _triggerGameOver() {
    status = GameStatus.gameOver;

    if (mdpl > highScore) {
      highScore = mdpl;
      _saveHighScore();
    }

    onGameOver?.call();
  }
}
