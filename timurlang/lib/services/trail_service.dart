// ============================================
// TimurLang - Trail Service
// Menghasilkan data jalur pendakian (polylines & checkpoints)
// untuk seluruh basecamp resmi 46 gunung di Indonesia
// Terkalibrasi secara geodetik agar tidak pernah loncat antar pulau
// ============================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/mountain.dart';
import '../models/basecamp_post.dart';

class TrailCheckpoint {
  final String name;
  final LatLng location;
  final int elevationMdpl;
  final String description;
  final bool hasWater;

  const TrailCheckpoint({
    required this.name,
    required this.location,
    required this.elevationMdpl,
    required this.description,
    this.hasWater = false,
  });
}

class HikingTrail {
  final String id;
  final String basecampId;
  final String gunungId;
  final String basecampName;
  final String mountainName;
  final Color color;
  final LatLng basecampLocation;
  final LatLng summitLocation;
  final List<LatLng> waypoints;
  final List<TrailCheckpoint> checkpoints;
  final double distanceKm;
  final int estimatedHours;
  final String statusJalur;
  final BasecampPost basecampPost;

  HikingTrail({
    required this.id,
    required this.basecampId,
    required this.gunungId,
    required this.basecampName,
    required this.mountainName,
    required this.color,
    required this.basecampLocation,
    required this.summitLocation,
    required this.waypoints,
    required this.checkpoints,
    required this.distanceKm,
    required this.estimatedHours,
    required this.statusJalur,
    required this.basecampPost,
  });
}

class TrailService {
  static final TrailService instance = TrailService._internal();
  TrailService._internal();

  // Palet warna estetik untuk jalur di peta
  static const List<Color> _trailColors = [
    Color(0xFF2ECC71), // Emerald
    Color(0xFFFF9F43), // Amber Orange
    Color(0xFF00D2D3), // Cyan
    Color(0xFFFF6B6B), // Coral Red
    Color(0xFF54A0FF), // Neon Blue
    Color(0xFF5F27CD), // Purple
    Color(0xFF10AC84), // Teal Green
    Color(0xFFFF9FF3), // Pink
  ];

  /// Mendapatkan semua jalur untuk suatu gunung
  List<HikingTrail> getTrailsForMountain(Mountain mountain, List<BasecampPost> basecamps) {
    final mountainBasecamps = basecamps.where((bc) => bc.gunungId == mountain.id).toList();
    if (mountainBasecamps.isEmpty) return [];

    final List<HikingTrail> trails = [];
    final summit = LatLng(mountain.koordinatLat, mountain.koordinatLong);

    for (int i = 0; i < mountainBasecamps.length; i++) {
      final bc = mountainBasecamps[i];
      final color = _trailColors[i % _trailColors.length];

      // Tentukan koordinat basecamp di lereng gunung dengan jaminan batas geodetis
      final bcCoord = _getBasecampCoordinate(bc, mountain, i, mountainBasecamps.length);
      final waypoints = _generateProceduralTrail(bcCoord, summit, i);

      final trail = HikingTrail(
        id: 'trail-${bc.id}',
        basecampId: bc.id,
        gunungId: mountain.id,
        basecampName: bc.namaPos,
        mountainName: mountain.namaGunung,
        color: color,
        basecampLocation: bcCoord,
        summitLocation: summit,
        waypoints: waypoints,
        checkpoints: _generateCheckpointsFromWaypoints(bc.namaPos, waypoints, mountain.elevasiMdpl),
        distanceKm: _calculateTrailDistance(waypoints),
        estimatedHours: max(3, (mountain.elevasiMdpl / 550).round()),
        statusJalur: bc.statusJalur,
        basecampPost: bc,
      );
      trails.add(trail);
    }

    return trails;
  }

  /// Menentukan koordinat basecamp di lereng gunung
  /// Menggunakan koordinat spesifik jika valid dan dekat dengan puncak (< 9 km),
  /// atau menggunakan perhitungan radial lereng gunung agar PASTI berada di gunung yang sama.
  LatLng _getBasecampCoordinate(BasecampPost bc, Mountain mountain, int index, int totalBasecamps) {
    final summit = LatLng(mountain.koordinatLat, mountain.koordinatLong);

    // 1. Cek koordinat terkalibrasi berdasarkan nama gunung dan nama pos
    final specificCoord = _lookupSpecificCoordinate(mountain.namaGunung, bc.namaPos);
    if (specificCoord != null) {
      // Validasi ketat: jarak titik basecamp TIDAK BOLEH melebihi 9 km dari puncak gunung
      final distKm = _calculateDistance(specificCoord, summit);
      if (distKm <= 9.0) {
        return specificCoord;
      }
    }

    // 2. Jika tidak ada atau melewati batas wajar, hitung posisi radial di lereng gunung
    // 0.01 derajat lat/long ≈ 1.11 km
    // radiusDegrees: 0.035 - 0.048 (~3.8 km - 5.3 km dari puncak)
    final radiusDegrees = 0.038 + ((index % 3) * 0.005);

    // Sebar sudut arah basecamp mengelilingi lereng gunung
    final angle = (2 * pi / max(1, totalBasecamps)) * index + (pi / 5);

    final bcLat = mountain.koordinatLat + (sin(angle) * radiusDegrees);
    final bcLong = mountain.koordinatLong + (cos(angle) * radiusDegrees);

    return LatLng(bcLat, bcLong);
  }

  /// Peta koordinat basecamp presisi di lereng gunung berdasarkan nama
  LatLng? _lookupSpecificCoordinate(String mountainName, String bcName) {
    final mLower = mountainName.toLowerCase();
    final bcLower = bcName.toLowerCase();

    // Gunung Sindoro (Jawa Tengah - Summit: -7.3008, 109.9981)
    if (mLower.contains('sindoro')) {
      if (bcLower.contains('kledung')) return const LatLng(-7.338, 110.024); // Tenggara
      if (bcLower.contains('sigedang')) return const LatLng(-7.272, 109.972); // Barat Laut
      if (bcLower.contains('bansari')) return const LatLng(-7.295, 110.041); // Timur
      if (bcLower.contains('bedakah')) return const LatLng(-7.342, 109.992); // Selatan
      if (bcLower.contains('ndoro arum') || bcLower.contains('arum')) return const LatLng(-7.268, 110.022); // Timur Laut
      if (bcLower.contains('alang')) return const LatLng(-7.312, 109.958); // Barat
    }

    // Gunung Sumbing (Jawa Tengah - Summit: -7.3842, 110.0700)
    if (mLower.contains('sumbing')) {
      if (bcLower.contains('garung')) return const LatLng(-7.375, 110.024);
      if (bcLower.contains('butuh') || bcLower.contains('kaliangkrik')) return const LatLng(-7.417, 110.088);
      if (bcLower.contains('mangli')) return const LatLng(-7.428, 110.098);
      if (bcLower.contains('bowongso')) return const LatLng(-7.412, 109.998);
      if (bcLower.contains('cepit') || bcLower.contains('parakan')) return const LatLng(-7.348, 110.042);
    }

    // Gunung Merbabu (Jawa Tengah - Summit: -7.4550, 110.4397)
    if (mLower.contains('merbabu')) {
      if (bcLower.contains('selo')) return const LatLng(-7.498, 110.457);
      if (bcLower.contains('suwanting')) return const LatLng(-7.472, 110.388);
      if (bcLower.contains('wekas')) return const LatLng(-7.439, 110.415);
      if (bcLower.contains('cuntel')) return const LatLng(-7.421, 110.428);
      if (bcLower.contains('thekelan')) return const LatLng(-7.412, 110.435);
    }

    // Gunung Prau (Jawa Tengah - Summit: -7.1878, 109.9214)
    if (mLower.contains('prau')) {
      if (bcLower.contains('patak banteng')) return const LatLng(-7.228, 109.914);
      if (bcLower.contains('dieng')) return const LatLng(-7.206, 109.907);
      if (bcLower.contains('kalilembu')) return const LatLng(-7.215, 109.911);
      if (bcLower.contains('wates')) return const LatLng(-7.195, 109.972);
      if (bcLower.contains('igirmrg')) return const LatLng(-7.218, 109.952);
    }

    // Gunung Slamet (Jawa Tengah - Summit: -7.2425, 109.2081)
    if (mLower.contains('slamet')) {
      if (bcLower.contains('bambangan')) return const LatLng(-7.242, 109.262);
      if (bcLower.contains('dipajaya')) return const LatLng(-7.221, 109.227);
      if (bcLower.contains('guci')) return const LatLng(-7.205, 109.185);
      if (bcLower.contains('baturraden')) return const LatLng(-7.295, 109.221);
    }

    // Gunung Lawu (Jawa Tengah / Jawa Timur - Summit: -7.6258, 111.1925)
    if (mLower.contains('lawu')) {
      if (bcLower.contains('sewu')) return const LatLng(-7.662, 111.192);
      if (bcLower.contains('kandang')) return const LatLng(-7.665, 111.189);
      if (bcLower.contains('cetho')) return const LatLng(-7.595, 111.157);
      if (bcLower.contains('singolangu')) return const LatLng(-7.645, 111.218);
    }

    // Gunung Gede (Jawa Barat - Summit: -6.7833, 106.9833)
    if (mLower.contains('gede')) {
      if (bcLower.contains('putri')) return const LatLng(-6.758, 107.001);
      if (bcLower.contains('cibodas')) return const LatLng(-6.741, 106.993);
    }

    // Gunung Pangrango (Jawa Barat - Summit: -6.7700, 106.9639)
    if (mLower.contains('pangrango')) {
      if (bcLower.contains('cibodas')) return const LatLng(-6.741, 106.993);
      if (bcLower.contains('putri')) return const LatLng(-6.758, 107.001);
      if (bcLower.contains('selabintana')) return const LatLng(-6.829, 106.968);
    }

    // Gunung Ciremai (Jawa Barat - Summit: -6.8925, 108.4056)
    if (mLower.contains('ciremai')) {
      if (bcLower.contains('apuy')) return const LatLng(-6.896, 108.352);
      if (bcLower.contains('linggajati') || bcLower.contains('linggarjati')) return const LatLng(-6.882, 108.472);
      if (bcLower.contains('palutungan')) return const LatLng(-6.953, 108.438);
      if (bcLower.contains('sadarahe') || bcLower.contains('trisakti')) return const LatLng(-6.862, 108.368);
    }

    // Gunung Rinjani (Lombok NTB - Summit: -8.4114, 116.4572)
    if (mLower.contains('rinjani')) {
      if (bcLower.contains('sembalun')) return const LatLng(-8.358, 116.527);
      if (bcLower.contains('senaru')) return const LatLng(-8.303, 116.408);
      if (bcLower.contains('torean')) return const LatLng(-8.288, 116.442);
      if (bcLower.contains('air berik')) return const LatLng(-8.482, 116.358);
      if (bcLower.contains('tetebatu')) return const LatLng(-8.512, 116.408);
      if (bcLower.contains('timbanuh')) return const LatLng(-8.485, 116.442);
    }

    // Gunung Semeru (Jawa Timur - Summit: -8.1081, 112.9225)
    if (mLower.contains('semeru')) {
      if (bcLower.contains('ranu pane') || bcLower.contains('ranu pani')) return const LatLng(-8.014, 112.951);
    }

    // Gunung Batur (Bali - Summit: -8.2424, 115.3753)
    if (mLower.contains('batur')) {
      if (bcLower.contains('pasar agung')) return const LatLng(-8.261, 115.392);
      if (bcLower.contains('toya bungkah')) return const LatLng(-8.252, 115.405);
    }

    // Gunung Kerinci (Jambi/Sumatra - Summit: -1.6967, 101.2642)
    if (mLower.contains('kerinci')) {
      if (bcLower.contains('kersik')) return const LatLng(-1.758, 101.272);
    }

    return null;
  }

  /// Menghasilkan rute berkelok alami (switchbacks gunung) dari basecamp ke puncak
  List<LatLng> _generateProceduralTrail(LatLng start, LatLng end, int seedIndex) {
    const int segments = 6;
    final List<LatLng> points = [start];

    final dLat = (end.latitude - start.latitude) / segments;
    final dLong = (end.longitude - start.longitude) / segments;

    // Vektor tegak lurus untuk kelokan jalur punggungan
    final perpLat = -dLong;
    final perpLong = dLat;

    final random = Random(seedIndex * 1337 + 42);

    for (int i = 1; i < segments; i++) {
      final t = i / segments;
      // Amplitudo kelokan mengecil saat mendekati puncak
      final curveFactor = sin(t * pi);
      final offsetAmount = (random.nextDouble() * 0.4 - 0.2) * curveFactor;

      final lat = start.latitude + (dLat * i) + (perpLat * offsetAmount);
      final long = start.longitude + (dLong * i) + (perpLong * offsetAmount);

      points.add(LatLng(lat, long));
    }

    points.add(end);
    return points;
  }

  List<TrailCheckpoint> _generateCheckpointsFromWaypoints(String bcName, List<LatLng> waypoints, int peakElevasi) {
    final List<TrailCheckpoint> cps = [];
    final int count = waypoints.length;
    final int baseElevasi = max(600, (peakElevasi * 0.45).round());

    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final elevasi = (baseElevasi + (peakElevasi - baseElevasi) * t).round();

      if (i == 0) {
        cps.add(TrailCheckpoint(
          name: 'Pos 0: Basecamp $bcName',
          location: waypoints[i],
          elevationMdpl: elevasi,
          description: 'Pusat registrasi, verifikasi tiket simaksi & briefing keselamatan',
          hasWater: true,
        ));
      } else if (i == count - 1) {
        cps.add(TrailCheckpoint(
          name: 'Puncak Tertinggi',
          location: waypoints[i],
          elevationMdpl: peakElevasi,
          description: 'Titik puncak tertinggi dengan panorama 360 derajat',
          hasWater: false,
        ));
      } else if (i == (count / 2).round()) {
        cps.add(TrailCheckpoint(
          name: 'Pos $i: Shelter & Camp Area',
          location: waypoints[i],
          elevationMdpl: elevasi,
          description: 'Area pendirian tenda utama dan sumber mata air',
          hasWater: true,
        ));
      } else {
        cps.add(TrailCheckpoint(
          name: 'Pos $i',
          location: waypoints[i],
          elevationMdpl: elevasi,
          description: 'Pos peristirahatan dan cek batas vegetasi',
          hasWater: i % 2 == 1,
        ));
      }
    }

    return cps;
  }

  double _calculateTrailDistance(List<LatLng> points) {
    const Distance distance = Distance();
    double totalMeters = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalMeters += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return double.parse((totalMeters / 1000).toStringAsFixed(1));
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, a, b);
  }
}
