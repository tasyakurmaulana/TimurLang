// ============================================
// TimurLang - Mountain Climber Game Models
// Player, Obstacle, Parallax Layer data classes
// ============================================

import 'dart:math';
import 'dart:ui';
import 'game_constants.dart';

/// Represents the player character (pendaki)
class Player {
  double x;
  double y;
  double width;
  double height;
  double velocityY;
  PlayerState state;
  double animationFrame;
  bool isOnGround;
  bool canDoubleJump;
  bool isDoubleJumping;
  double doubleJumpEffectTime;

  Player({
    required this.x,
    required this.y,
    this.width = GameConstants.playerWidth,
    this.height = GameConstants.playerHeight,
    this.velocityY = 0,
    this.state = PlayerState.berlari,
    this.animationFrame = 0,
    this.isOnGround = true,
    this.canDoubleJump = false,
    this.isDoubleJumping = false,
    this.doubleJumpEffectTime = 0,
  });

  Rect get hitbox {
    // Slightly smaller hitbox for forgiving gameplay
    const margin = 6.0;
    if (state == PlayerState.menunduk) {
      return Rect.fromLTWH(
        x + margin,
        y + (GameConstants.playerHeight - GameConstants.playerDuckHeight) + margin,
        width - margin * 2,
        GameConstants.playerDuckHeight - margin * 2,
      );
    }
    if (state == PlayerState.melompat) {
      // Saat melompat, kaki ditekuk (visual kaki di y + 52)
      return Rect.fromLTWH(
        x + margin,
        y + margin,
        width - margin * 2,
        50.0 - margin * 2,
      );
    }
    return Rect.fromLTWH(
      x + margin,
      y + margin,
      width - margin * 2,
      height - margin * 2,
    );
  }

  /// Melompat:
  /// - Tap ke-1 (saat di tanah): lompatan reguler
  /// - Tap ke-2 (di udara): lompatan kedua (double jump) untuk jangkauan lebih jauh!
  ({bool success, bool isDoubleJump}) jump() {
    if (isOnGround && state != PlayerState.menunduk) {
      velocityY = GameConstants.jumpVelocity;
      isOnGround = false;
      canDoubleJump = true;
      isDoubleJumping = false;
      doubleJumpEffectTime = 0;
      state = PlayerState.melompat;
      return (success: true, isDoubleJump: false);
    } else if (!isOnGround && canDoubleJump) {
      // Lompatan kedua di udara: dorong kembali ke atas agar melayang jauh lebih lama
      velocityY = GameConstants.doubleJumpVelocity;
      canDoubleJump = false;
      isDoubleJumping = true;
      doubleJumpEffectTime = 0.35;
      state = PlayerState.melompat;
      return (success: true, isDoubleJump: true);
    }
    return (success: false, isDoubleJump: false);
  }

  void duck() {
    if (isOnGround) {
      state = PlayerState.menunduk;
    }
  }

  void standUp() {
    if (state == PlayerState.menunduk) {
      state = PlayerState.berlari;
    }
  }

  void update(double dt, double groundY) {
    if (doubleJumpEffectTime > 0) {
      doubleJumpEffectTime = (doubleJumpEffectTime - dt).clamp(0.0, 1.0);
    }

    if (!isOnGround) {
      velocityY += GameConstants.gravity * dt;
      y += velocityY * dt;

      if (y >= groundY - height) {
        y = groundY - height;
        velocityY = 0;
        isOnGround = true;
        canDoubleJump = false;
        isDoubleJumping = false;
        doubleJumpEffectTime = 0;
        if (state == PlayerState.melompat) {
          state = PlayerState.berlari;
        }
      }
    }

    // Animate running
    animationFrame += dt * 10;
    if (animationFrame >= 4) animationFrame = 0;
  }

  void reset(double groundY) {
    y = groundY - height;
    velocityY = 0;
    state = PlayerState.berlari;
    isOnGround = true;
    canDoubleJump = false;
    isDoubleJumping = false;
    doubleJumpEffectTime = 0;
    animationFrame = 0;
  }
}

/// Represents an obstacle in the game
class Obstacle {
  double x;
  double y;
  double width;
  double height;
  ObstacleType type;
  String name;
  bool passed;

  Obstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    required this.name,
    this.passed = false,
  });

  Rect get hitbox {
    const margin = 6.0;
    return Rect.fromLTWH(
      x + margin,
      y + margin,
      width - margin * 2,
      height - margin * 2,
    );
  }

  void update(double dt, double speed) {
    x -= speed * dt;
  }

  bool get isOffScreen => x + width < -20;
}

/// Parallax background layer
class ParallaxLayer {
  double offset;
  final double speedRatio;
  final List<double> segments; // pre-generated segment heights

  ParallaxLayer({
    this.offset = 0,
    required this.speedRatio,
    List<double>? segments,
  }) : segments = segments ?? _generateSegments();

  static List<double> _generateSegments() {
    final random = Random();
    return List.generate(20, (_) => 0.3 + random.nextDouble() * 0.5);
  }

  void update(double dt, double speed) {
    offset += speed * speedRatio * dt;
  }
}

/// Star data for night sky
class Star {
  final double x;
  final double y;
  final double size;
  final double twinkleOffset;
  double brightness;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleOffset,
    this.brightness = 1.0,
  });
}
