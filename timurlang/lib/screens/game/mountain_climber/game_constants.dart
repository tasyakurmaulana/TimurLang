// ============================================
// TimurLang - Mountain Climber Game Constants
// All tunable game parameters in one place
// ============================================

import 'package:flutter/material.dart';

/// Sky phase transitions based on MDPL score
enum SkyPhase { pagi, senja, malam }

/// Obstacle type categorization
enum ObstacleType { bawah, atas }

/// Player state
enum PlayerState { berlari, melompat, menunduk }

/// Game status
enum GameStatus { ready, running, gameOver }

class GameConstants {
  // ── Canvas & Physics ──
  static const double gravity = 3600.0;
  static const double jumpVelocity = -980.0; // Lengkungan lompat reguler
  static const double doubleJumpVelocity = -920.0; // Lompatan kedua (double tap) untuk jangkauan lebih jauh
  static const double groundHeightRatio = 0.18; // ground height as ratio of screen

  // ── Player ──
  static const double playerWidth = 48.0;
  static const double playerHeight = 72.0;
  static const double playerDuckHeight = 44.0;
  static const double playerXPosition = 60.0; // fixed X position from left (matching left: 60)

  // ── Speed & Difficulty ──
  static const double initialSpeed = 320.0;
  static const double maxSpeed = 800.0;
  static const double speedIncreasePerMdpl = 0.15; // speed increase per MDPL unit
  static const double mdplPerSecond = 8.0; // base MDPL gain per second

  // ── Obstacle Spawning ──
  static const double minObstacleGap = 280.0;
  static const double maxObstacleGap = 550.0;
  static const double obstacleSpawnVariation = 0.35;

  // ── Sky Phase Thresholds (MDPL) ──
  // Berganti suasana sky phase setiap kelipatan 1000 MDPL (Pagi -> Senja -> Malam -> Pagi ...)
  static const double skyPhaseInterval = 1000.0;
  static const double skyTransitionLength = 200.0;
  static const double senjaThreshold = 1000.0;
  static const double malamThreshold = 2000.0;
  static const double senjaTransitionLength = 200.0;
  static const double malamTransitionLength = 200.0;

  // ── Sky Colors per Phase ──
  static const List<Color> pagiSkyColors = [
    Color(0xFF87CEEB), // light blue
    Color(0xFFB0E0E6), // powder blue
    Color(0xFFE0F7FA), // light cyan near horizon
  ];

  static const List<Color> senjaSkyColors = [
    Color(0xFF1A237E), // deep indigo at top
    Color(0xFFE65100), // deep orange
    Color(0xFFFFCC02), // golden at horizon
  ];

  static const List<Color> malamSkyColors = [
    Color(0xFF0D0D2B), // near black
    Color(0xFF1A1A3E), // dark navy
    Color(0xFF2C2C54), // slightly lighter at horizon
  ];

  // ── Parallax Layer Speeds (relative to game speed) ──
  static const double farMountainSpeedRatio = 0.15;
  static const double nearMountainSpeedRatio = 0.30;
  static const double treesSpeedRatio = 0.55;
  static const double fogSpeedRatio = 0.20;
  static const double groundSpeedRatio = 1.0;

  // ── Obstacle Definitions (Aset Aktual Game) ──
  // Rintangan bawah darat: Rubah (fox.png), Rintangan atas udara: Burung Elang (elang.png)
  static const double foxWidth = 84.6;
  static const double foxHeight = 44.0;
  static const double woodSize = 46.0;
  static const double eagleWidth = 68.0;
  static const double eagleHeight = 48.0;
  static const double eagleAltitude = 68.0;

  static const List<Map<String, dynamic>> bottomObstacles = [
    {'name': 'rubah', 'width': 84.6, 'height': 44.0},
    {'name': 'kayu', 'width': 46.0, 'height': 46.0},
  ];

  static const List<Map<String, dynamic>> topObstacles = [
    {'name': 'elang', 'width': 68.0, 'height': 48.0},
  ];

  // ── Star Configuration ──
  static const int maxStars = 60;
  static const double starTwinkleSpeed = 3.0;
}
