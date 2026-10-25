// ============================================
// TimurLang - Trail Service
// Menghasilkan data jalur pendakian (polylines & checkpoints)
// untuk seluruh basecamp resmi 46 gunung di Indonesia
// Terkalibrasi secara geodetik agar tidak pernah loncat antar pulau
// ============================================

import 'dart:convert';
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

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'elevation_mdpl': elevationMdpl,
      'description': description,
      'has_water': hasWater,
    };
  }

  factory TrailCheckpoint.fromMap(Map<String, dynamic> map) {
    return TrailCheckpoint(
      name: (map['name'] as String?) ?? 'Pos Pendakian',
      location: LatLng(
        (map['latitude'] as num?)?.toDouble() ?? 0.0,
        (map['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      elevationMdpl: (map['elevation_mdpl'] as num?)?.toInt() ?? 1000,
      description: (map['description'] as String?) ?? '',
      hasWater: map['has_water'] == true || map['has_water'] == 1,
    );
  }

  static String listToJson(List<TrailCheckpoint> list) {
    return jsonEncode(list.map((c) => c.toMap()).toList());
  }

  static List<TrailCheckpoint> listFromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((m) => TrailCheckpoint.fromMap(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('⚠️ Error decoding TrailCheckpoint list: $e');
    }
    return [];
  }

  TrailCheckpoint copyWith({
    String? name,
    LatLng? location,
    int? elevationMdpl,
    String? description,
    bool? hasWater,
  }) {
    return TrailCheckpoint(
      name: name ?? this.name,
      location: location ?? this.location,
      elevationMdpl: elevationMdpl ?? this.elevationMdpl,
      description: description ?? this.description,
      hasWater: hasWater ?? this.hasWater,
    );
  }
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
        checkpoints: (bc.checkpointsJson != null && bc.checkpointsJson!.trim().isNotEmpty)
            ? _parseCustomCheckpoints(bc.checkpointsJson!, waypoints, mountain.elevasiMdpl)
            : _generateCheckpointsFromWaypoints(bc.namaPos, waypoints, mountain.elevasiMdpl),
        distanceKm: _calculateTrailDistance(waypoints),
        estimatedHours: max(3, (mountain.elevasiMdpl / 550).round()),
        statusJalur: bc.statusJalur,
        basecampPost: bc,
      );
      trails.add(trail);
    }

    return trails;
  }

  /// Peta koordinat terkalibrasi presisi untuk seluruh 122 basecamp resmi Indonesia
  static const Map<String, LatLng> _basecampIdCoordinates = {
    // 1. Gunung Leuser (mtn-001)
    'bc-001': LatLng(3.9780, 97.2450), // Kedah Desa Penosan Sepakat (Blangjerango, Gayo Lues)

    // 2. Gunung Batur (mtn-002)
    'bc-002': LatLng(-8.2615, 115.3920), // Pura Pasar Agung Bangli (Kintamani)

    // 3. Gunung Kerinci (mtn-003)
    'bc-003': LatLng(-1.7510, 101.2580), // Kersik Tuo Kerinci (Kayu Aro)

    // 4. Gunung Gede (mtn-004)
    'bc-004': LatLng(-6.7565, 107.0022), // Gunung Putri Cianjur
    'bc-005': LatLng(-6.7412, 106.9932), // Cibodas Cianjur

    // 5. Gunung Pangrango (mtn-005)
    'bc-006': LatLng(-6.7412, 106.9932), // Cibodas Cianjur
    'bc-007': LatLng(-6.7565, 107.0022), // Gunung Putri Cianjur
    'bc-008': LatLng(-6.8320, 106.9680), // Selabintana Sukabumi

    // 6. Gunung Bongkok (mtn-006)
    'bc-009': LatLng(-6.6650, 107.3480), // Sukamulya Purwakarta

    // 7. Gunung Cikuray (mtn-007)
    'bc-010': LatLng(-7.3180, 107.8180), // Tapak Geurot Garut (Bayongbong)
    'bc-011': LatLng(-7.2880, 107.8820), // Pamancar Garut (Pemancar Cilawu)

    // 8. Gunung Kerenceng (mtn-008)
    'bc-012': LatLng(-6.9480, 107.8850), // Babakan Jambuaer Sumedang

    // 9. Gunung Burangrang (mtn-009)
    'bc-013': LatLng(-6.7580, 107.5450), // Legok Haji Cisarua

    // 10. Gunung Patuha (mtn-010)
    'bc-014': LatLng(-7.1680, 107.3950), // Cipanganten Bandung (Ciwidey)

    // 11. Gunung Sagara (mtn-011)
    'bc-015': LatLng(-7.1980, 108.0820), // Sukahurip Garut / Tajur

    // 12. Gunung Guntur (mtn-012)
    'bc-016': LatLng(-7.1680, 107.8680), // Citiis Tarogong Kaler Garut
    'bc-017': LatLng(-7.1550, 107.8650), // Cikahuripan Garut

    // 13. Gunung Ciremai (mtn-013)
    'bc-018': LatLng(-6.9530, 108.4380), // Palutungan Kuningan
    'bc-019': LatLng(-6.8820, 108.4720), // Linggajati Kuningan
    'bc-020': LatLng(-6.8920, 108.4750), // Linggasana Kuningan
    'bc-021': LatLng(-6.8960, 108.3520), // Apuy Majalengka
    'bc-022': LatLng(-6.8620, 108.3680), // Trisakti Sadarahe Majalengka

    // 14. Gunung Merbabu (mtn-014)
    'bc-023': LatLng(-7.4980, 110.4570), // Selo Boyolali
    'bc-024': LatLng(-7.4720, 110.3880), // Suwanting Magelang
    'bc-025': LatLng(-7.4390, 110.4150), // Wekas Magelang
    'bc-026': LatLng(-7.4210, 110.4280), // Cuntel Kopeng Semarang
    'bc-027': LatLng(-7.4120, 110.4350), // Thekelan Semarang

    // 15. Gunung Lawu (mtn-015)
    'bc-028': LatLng(-7.6620, 111.1920), // Cemoro Sewu Magetan
    'bc-029': LatLng(-7.6650, 111.1890), // Cemoro Kandang Karanganyar
    'bc-030': LatLng(-7.5950, 111.1570), // Candi Cetho Karanganyar
    'bc-031': LatLng(-7.5980, 111.1680), // Tambak Karanganyar
    'bc-032': LatLng(-7.6450, 111.2180), // Singolangu Magetan

    // 16. Gunung Kembang (mtn-016)
    'bc-033': LatLng(-7.3820, 109.9120), // Lengkong Wonosobo
    'bc-034': LatLng(-7.3780, 109.9280), // Blembem Wonosobo

    // 17. Gunung Sindoro (mtn-017)
    'bc-035': LatLng(-7.3380, 110.0240), // Kledung Temanggung
    'bc-036': LatLng(-7.2720, 109.9720), // Sigedang Wonosobo
    'bc-037': LatLng(-7.2950, 110.0410), // Bansari Temanggung
    'bc-038': LatLng(-7.3420, 109.9920), // Bedakah Wonosobo
    'bc-039': LatLng(-7.2680, 110.0220), // Ndoro Arum
    'bc-040': LatLng(-7.3120, 109.9580), // Alang Alang Sewu Wonosobo

    // 18. Gunung Bismo (mtn-018)
    'bc-041': LatLng(-7.2280, 109.9320), // Sikunang Wonosobo
    'bc-042': LatLng(-7.2420, 109.9250), // Ngandam Wonosobo
    'bc-043': LatLng(-7.2480, 109.9380), // Silandak Wonosobo

    // 19. Gunung Rogojembangan (mtn-019)
    'bc-044': LatLng(-7.1550, 109.6820), // Desa Gumelem Pekalongan

    // 20. Gunung Prau (mtn-020)
    'bc-045': LatLng(-7.2180, 109.9140), // Petakbanteng Wonosobo
    'bc-046': LatLng(-7.2210, 109.9250), // Igirmanak Wonosobo
    'bc-047': LatLng(-7.1950, 109.9720), // Wates Temanggung
    'bc-048': LatLng(-7.2060, 109.9070), // Dwarawati Banjarnegara
    'bc-049': LatLng(-7.2150, 109.9110), // Kalilembu Wonosobo
    'bc-050': LatLng(-7.2090, 109.9050), // Dieng Wonosobo

    // 21. Gunung Andong (mtn-021)
    'bc-051': LatLng(-7.3948, 110.3693), // Sawit Magelang (Dusun Sawit, Girirejo)
    'bc-052': LatLng(-7.3831, 110.3719), // Gogik Magelang (Dusun Gogik, Girirejo)
    'bc-053': LatLng(-7.3968, 110.3585), // Pendem Magelang (Dusun Pendem, Girirejo)

    // 22. Gunung Slamet (mtn-022)
    'bc-054': LatLng(-7.2420, 109.2620), // Bambangan Purbalingga
    'bc-055': LatLng(-7.2950, 109.2210), // Baturraden Purwokerto
    'bc-056': LatLng(-7.2350, 109.1620), // Kaliwadas Brebes
    'bc-057': LatLng(-7.2210, 109.2270), // Dipajaya Pemalang
    'bc-058': LatLng(-7.2120, 109.2420), // Cemara Sakti Pemalang
    'bc-059': LatLng(-7.2050, 109.1850), // Guci Tegal

    // 23. Gunung Sumbing (mtn-023)
    'bc-060': LatLng(-7.4280, 110.0980), // Mangli Magelang
    'bc-061': LatLng(-7.4120, 109.9980), // Bowongso Wonosobo
    'bc-062': LatLng(-7.3520, 110.0520), // Sipetung Temanggung
    'bc-063': LatLng(-7.3750, 110.0240), // Garung Wonosobo
    'bc-064': LatLng(-7.4170, 110.0880), // Butuh Temanggung (Nepal Van Java Kaliangkrik)
    'bc-065': LatLng(-7.3620, 110.0650), // Banaran Temanggung

    // 24. Gunung Ungaran (mtn-024)
    'bc-066': LatLng(-7.1950, 110.3580), // Mawar Camp Semarang
    'bc-067': LatLng(-7.1980, 110.3450), // Perantunan Semarang
    'bc-068': LatLng(-7.1620, 110.3340), // Promasan Semarang

    // 25. Gunung Merapi (mtn-025)
    'bc-069': LatLng(-7.5080, 110.4520), // Selo Boyolali
    'bc-070': LatLng(-7.5340, 110.4080), // Babadan Magelang
    'bc-071': LatLng(-7.5450, 110.4780), // Sapuangin Klaten
    'bc-072': LatLng(-7.5920, 110.4420), // Kinahrejo Sleman

    // 26. Gunung Saeng (mtn-026)
    'bc-073': LatLng(-7.9520, 113.8850), // Sumber Waru Bondowoso

    // 27. Gunung Raung (mtn-027)
    'bc-074': LatLng(-8.2380, 114.0050), // Kalibaru Banyuwangi
    'bc-075': LatLng(-8.0420, 114.0280), // Sumber Wringin Bondowoso

    // 28. Gunung Penanggungan (mtn-028)
    'bc-076': LatLng(-7.6450, 112.5980), // Tamiajeng Mojokerto
    'bc-077': LatLng(-7.6180, 112.5820), // Jolotundo Mojokerto
    'bc-078': LatLng(-7.6480, 112.6250), // Kedungudi Mojokerto

    // 29. Gunung Kelud (mtn-029)
    'bc-079': LatLng(-7.9350, 112.2850), // Karangrejo Blitar
    'bc-080': LatLng(-7.9420, 112.2980), // Tulungrejo Blitar

    // 30. Gunung Arjuno (mtn-030)
    'bc-081': LatLng(-7.7610, 112.6680), // Tambaksari Pasuruan (Purwosari)
    'bc-082': LatLng(-7.7650, 112.5320), // Sumber Brantas Batu
    'bc-083': LatLng(-7.8250, 112.6580), // Lawang Malang
    'bc-084': LatLng(-7.6980, 112.6310), // Tretes Pasuruan

    // 31. Gunung Argopuro (mtn-031)
    'bc-085': LatLng(-7.9120, 113.4980), // Bremi Probolinggo
    'bc-086': LatLng(-7.8880, 113.6280), // Baderan Situbondo

    // 32. Gunung Semeru (mtn-032)
    'bc-087': LatLng(-8.0140, 112.9510), // Ranu Pane Lumajang

    // 33. Gunung Bukit Raya (mtn-033)
    'bc-088': LatLng(-0.6850, 112.7210), // Tumbang Habangoi Katingan
    'bc-089': LatLng(-0.6120, 112.6850), // Rantau Malam Sintang

    // 34. Gunung Tanggamus (mtn-034)
    'bc-090': LatLng(-5.4420, 104.7250), // Sidokatan Tanggamus

    // 35. Gunung Gamalama (mtn-035)
    'bc-091': LatLng(0.8120, 127.3520), // Moya Ternate

    // 36. Gunung Rinjani (mtn-036)
    'bc-092': LatLng(-8.3610, 116.5290), // Sembalun Lombok Timur (Sembalun Lawang)
    'bc-093': LatLng(-8.2885, 116.4425), // Torean Lombok Utara (Loloan Bayan)
    'bc-094': LatLng(-8.3005, 116.4095), // Senaru Lombok Utara (Senaru Bayan)
    'bc-095': LatLng(-8.5200, 116.3530), // Aik Berik Lombok Tengah (Batukeling Utara)
    'bc-096': LatLng(-8.5350, 116.4190), // Tetebatu Lombok Timur (Sikur)
    'bc-097': LatLng(-8.5286, 116.4634), // Timbanuh Lombok Timur (Pringgasela)

    // 37. Gunung Bawakaraeng (mtn-037)
    'bc-098': LatLng(-5.3050, 119.9320), // Danau Tanralili Gowa
    'bc-099': LatLng(-5.2950, 119.9150), // Lembanna Gowa

    // 38. Gunung Latimojong (mtn-038)
    'bc-100': LatLng(-3.4150, 120.0050), // Karangan Enrekang
    'bc-101': LatLng(-3.4350, 120.0120), // To'lajuk Latimojong

    // 39. Gunung Bulu Baria (mtn-039)
    'bc-102': LatLng(-5.2380, 119.8950), // Manimbahoi Gowa

    // 40. Gunung Lompobattang (mtn-040)
    'bc-103': LatLng(-5.3620, 119.9050), // Tompobulu Gowa

    // 41. Gunung Bulu Mopeaanooleo (mtn-041)
    'bc-104': LatLng(-3.4050, 121.3250), // Desa Puncak Monapa Kolaka Utara

    // 42. Gunung Tangkelemboke (mtn-042)
    'bc-105': LatLng(-3.5320, 121.5620), // Desa Nesoi Konawe

    // 43. Gunung Talang (mtn-043)
    'bc-106': LatLng(-0.9580, 100.6820), // Air Batumbuk Solok
    'bc-107': LatLng(-0.9920, 100.6950), // Batu Bajanjang Solok
    'bc-108': LatLng(-0.9720, 100.6980), // Seroja Solok

    // 44. Gunung Dempo (mtn-044)
    'bc-109': LatLng(-4.0480, 103.1380), // Tugu Rimau Pagar Alam
    'bc-110': LatLng(-4.0580, 103.1480), // Balai Pendakian Kampung 4 Pagar Alam

    // 45. Gunung Sinabung (mtn-045)
    'bc-111': LatLng(3.1820, 98.3980), // Danau Lau Kawar Karo

    // 46. Gunung Sibuatan (mtn-046)
    'bc-112': LatLng(2.9320, 98.4350), // Pancur Batu Karo

    // 47. Gunung Telomoyo (mtn-047)
    'bc-113': LatLng(-7.3690, 110.3870), // Dalangan Magelang (Dusun Dalangan, Pandean, Ngablak)
    'bc-114': LatLng(-7.3750, 110.3920), // Pagar Gedok Magelang (Dusun Pagar Gedok, Ngablak)
    'bc-115': LatLng(-7.3387, 110.4077), // Sepakung Semarang (Desa Wisata Sepakung, Banyubiru)
    'bc-116': LatLng(-7.3720, 110.4080), // Arsal Magelang (Dusun Arsal, Campurejo, Ngablak)

    // 48. Gunung Pakuwaja (mtn-048)
    'bc-117': LatLng(-7.2225, 109.9125), // Parikesit Wonosobo (Desa Parikesit, Kejajar, Dieng)
    'bc-118': LatLng(-7.2370, 109.9120), // Sembungan Wonosobo (Desa Sembungan, Kejajar, Dieng)
    'bc-119': LatLng(-7.2180, 109.9070), // Patak Banteng Wonosobo (Desa Patakbanteng, Kejajar, Dieng)

    // 49. Gunung Carstensz (Puncak Jaya) (mtn-049)
    'bc-120': LatLng(-4.0795, 137.1580), // Yellow Valley Carstensz (Lembah Kuning Carstensz Pyramid)
    'bc-121': LatLng(-4.0680, 137.1520), // Lembah Danau-Danau Carstensz (Carstensz Meadow)

    // 50. Gunung Tambora (mtn-050)
    'bc-122': LatLng(-8.1880, 117.9780), // Pancasila Dompu (Dusun Pancasila, Desa Oi Bura, Pekat)
  };

  /// Menentukan koordinat basecamp di lereng gunung
  /// Menggunakan koordinat terkalibrasi presisi sesuai ID atau nama resmi di peta OpenStreetMap.
  LatLng _getBasecampCoordinate(BasecampPost bc, Mountain mountain, int index, int totalBasecamps) {
    final summit = LatLng(mountain.koordinatLat, mountain.koordinatLong);

    // 1. Cek koordinat terkalibrasi presisi berdasarkan ID basecamp, nama pos, dan nama gunung
    final specificCoord = _lookupSpecificCoordinate(mountain.namaGunung, bc.namaPos, bc.id);
    if (specificCoord != null) {
      // Validasi geodetis wajar: basecamp berada di lereng/kaki gunung (< 45 km)
      final distKm = _calculateDistance(specificCoord, summit);
      if (distKm <= 45.0) {
        return specificCoord;
      }
    }

    // 2. Fallback jika basecamp kustom tidak ada di tabel koordinat terkalibrasi:
    final double radiusDegrees;
    if (mountain.elevasiMdpl <= 2000) {
      radiusDegrees = 0.011 + ((index % 3) * 0.003);
    } else if (mountain.elevasiMdpl <= 3000) {
      radiusDegrees = 0.024 + ((index % 3) * 0.005);
    } else {
      radiusDegrees = 0.038 + ((index % 3) * 0.008);
    }

    final angle = (2 * pi / max(1, totalBasecamps)) * index + (pi / 5);
    final bcLat = mountain.koordinatLat + (sin(angle) * radiusDegrees);
    final bcLong = mountain.koordinatLong + (cos(angle) * radiusDegrees);

    return LatLng(bcLat, bcLong);
  }

  /// Peta koordinat basecamp presisi di lereng gunung berdasarkan ID atau nama resmi
  LatLng? _lookupSpecificCoordinate(String mountainName, String bcName, [String? basecampId]) {
    // 1. Cek langsung berdasarkan ID resmi basecamp
    if (basecampId != null && _basecampIdCoordinates.containsKey(basecampId)) {
      return _basecampIdCoordinates[basecampId];
    }

    final mLower = mountainName.toLowerCase();
    final bcLower = bcName.toLowerCase();

    // ── GUNUNG ANDONG (Jawa Tengah - Summit: -7.3872, 110.3644) ──
    if (mLower.contains('andong')) {
      if (bcLower.contains('sawit')) return const LatLng(-7.3948, 110.3693);
      if (bcLower.contains('pendem')) return const LatLng(-7.3968, 110.3585);
      if (bcLower.contains('gogik')) return const LatLng(-7.3831, 110.3719);
      if (bcLower.contains('sekararum') || bcLower.contains('sekar')) return const LatLng(-7.3980, 110.3640);
    }

    // ── GUNUNG TELOMOYO (Jawa Tengah - Summit: -7.3612, 110.4001) ──
    if (mLower.contains('telomoyo')) {
      if (bcLower.contains('dalangan')) return const LatLng(-7.3690, 110.3870);
      if (bcLower.contains('pagar gedok') || bcLower.contains('gedok')) return const LatLng(-7.3750, 110.3920);
      if (bcLower.contains('sepakung')) return const LatLng(-7.3387, 110.4077);
      if (bcLower.contains('arsal')) return const LatLng(-7.3720, 110.4080);
    }

    // ── GUNUNG PAKUWAJA (Jawa Tengah - Summit: -7.2183, 109.9192) ──
    if (mLower.contains('pakuwaja')) {
      if (bcLower.contains('parikesit')) return const LatLng(-7.2225, 109.9125);
      if (bcLower.contains('sembungan')) return const LatLng(-7.2370, 109.9120);
      if (bcLower.contains('patak banteng') || bcLower.contains('banteng')) return const LatLng(-7.2180, 109.9070);
    }

    // ── GUNUNG CARSTENSZ / CARTEINS / PUNCAK JAYA (Papua - Summit: -4.0789, 137.1595) ──
    if (mLower.contains('carstensz') || mLower.contains('carteins') || mLower.contains('puncak jaya')) {
      if (bcLower.contains('yellow valley') || bcLower.contains('yellow') || bcLower.contains('kuning')) return const LatLng(-4.0795, 137.1580);
      if (bcLower.contains('danau')) return const LatLng(-4.0680, 137.1520);
    }

    // ── GUNUNG TAMBORA (NTB - Summit: -8.2500, 117.9667) ──
    if (mLower.contains('tambora')) {
      if (bcLower.contains('pancasila')) return const LatLng(-8.1880, 117.9780);
      if (bcLower.contains('doro ncanga')) return const LatLng(-8.3750, 118.0050);
    }

    // ── GUNUNG RINJANI (Lombok NTB - Summit: -8.4114, 116.4572) ──
    if (mLower.contains('rinjani')) {
      if (bcLower.contains('sembalun')) return const LatLng(-8.3610, 116.5290);
      if (bcLower.contains('senaru')) return const LatLng(-8.3005, 116.4095);
      if (bcLower.contains('torean')) return const LatLng(-8.2885, 116.4425);
      if (bcLower.contains('aik berik') || bcLower.contains('air berik')) return const LatLng(-8.5200, 116.3530);
      if (bcLower.contains('tetebatu') || bcLower.contains('tete batu')) return const LatLng(-8.5350, 116.4190);
      if (bcLower.contains('timbanuh')) return const LatLng(-8.5286, 116.4634);
    }

    // ── GUNUNG MERBABU (Jawa Tengah - Summit: -7.4550, 110.4397) ──
    if (mLower.contains('merbabu')) {
      if (bcLower.contains('selo')) return const LatLng(-7.4980, 110.4570);
      if (bcLower.contains('suwanting')) return const LatLng(-7.4720, 110.3880);
      if (bcLower.contains('wekas')) return const LatLng(-7.4390, 110.4150);
      if (bcLower.contains('cuntel')) return const LatLng(-7.4210, 110.4280);
      if (bcLower.contains('thekelan')) return const LatLng(-7.4120, 110.4350);
    }

    // ── GUNUNG MERAPI (Yogyakarta / Jateng - Summit: -7.5407, 110.4457) ──
    if (mLower.contains('merapi')) {
      if (bcLower.contains('selo')) return const LatLng(-7.5080, 110.4520);
      if (bcLower.contains('kaliurang') || bcLower.contains('plunyon') || bcLower.contains('kinahrejo')) return const LatLng(-7.5920, 110.4420);
      if (bcLower.contains('babadan')) return const LatLng(-7.5340, 110.4080);
      if (bcLower.contains('sapuangin')) return const LatLng(-7.5450, 110.4780);
    }

    // ── GUNUNG SINDORO (Jawa Tengah - Summit: -7.3008, 109.9981) ──
    if (mLower.contains('sindoro')) {
      if (bcLower.contains('kledung')) return const LatLng(-7.3380, 110.0240);
      if (bcLower.contains('sigedang')) return const LatLng(-7.2720, 109.9720);
      if (bcLower.contains('bansari')) return const LatLng(-7.2950, 110.0410);
      if (bcLower.contains('bedakah')) return const LatLng(-7.3420, 109.9920);
      if (bcLower.contains('ndoro arum') || bcLower.contains('arum')) return const LatLng(-7.2680, 110.0220);
      if (bcLower.contains('alang')) return const LatLng(-7.3120, 109.9580);
    }

    // ── GUNUNG SUMBING (Jawa Tengah - Summit: -7.3842, 110.0700) ──
    if (mLower.contains('sumbing')) {
      if (bcLower.contains('garung')) return const LatLng(-7.3750, 110.0240);
      if (bcLower.contains('butuh') || bcLower.contains('kaliangkrik') || bcLower.contains('nepal')) return const LatLng(-7.4170, 110.0880);
      if (bcLower.contains('mangli')) return const LatLng(-7.4280, 110.0980);
      if (bcLower.contains('bowongso')) return const LatLng(-7.4120, 109.9980);
      if (bcLower.contains('sipetung')) return const LatLng(-7.3520, 110.0520);
      if (bcLower.contains('banaran')) return const LatLng(-7.3620, 110.0650);
    }

    // ── GUNUNG PRAU (Jawa Tengah - Summit: -7.1878, 109.9214) ──
    if (mLower.contains('prau')) {
      if (bcLower.contains('petakbanteng') || bcLower.contains('patak banteng')) return const LatLng(-7.2180, 109.9140);
      if (bcLower.contains('dieng') || bcLower.contains('dwarawati')) return const LatLng(-7.2060, 109.9070);
      if (bcLower.contains('kalilembu')) return const LatLng(-7.2150, 109.9110);
      if (bcLower.contains('wates')) return const LatLng(-7.1950, 109.9720);
      if (bcLower.contains('igirmanak')) return const LatLng(-7.2210, 109.9250);
    }

    // ── GUNUNG SLAMET (Jawa Tengah - Summit: -7.2425, 109.2081) ──
    if (mLower.contains('slamet')) {
      if (bcLower.contains('bambangan')) return const LatLng(-7.2420, 109.2620);
      if (bcLower.contains('dipajaya')) return const LatLng(-7.2210, 109.2270);
      if (bcLower.contains('guci')) return const LatLng(-7.2050, 109.1850);
      if (bcLower.contains('baturraden')) return const LatLng(-7.2950, 109.2210);
      if (bcLower.contains('kaliwadas')) return const LatLng(-7.2350, 109.1620);
      if (bcLower.contains('cemara sakti')) return const LatLng(-7.2120, 109.2420);
    }

    // ── GUNUNG LAWU (Jateng/Jatim - Summit: -7.6258, 111.1925) ──
    if (mLower.contains('lawu')) {
      if (bcLower.contains('sewu')) return const LatLng(-7.6620, 111.1920);
      if (bcLower.contains('kandang')) return const LatLng(-7.6650, 111.1890);
      if (bcLower.contains('cetho')) return const LatLng(-7.5950, 111.1570);
      if (bcLower.contains('singolangu')) return const LatLng(-7.6450, 111.2180);
      if (bcLower.contains('tambak')) return const LatLng(-7.5980, 111.1680);
    }

    // ── GUNUNG UNGARAN (Jawa Tengah - Summit: -7.1814, 110.3400) ──
    if (mLower.contains('ungaran')) {
      if (bcLower.contains('mawar')) return const LatLng(-7.1950, 110.3580);
      if (bcLower.contains('perantunan') || bcLower.contains('gedong')) return const LatLng(-7.1980, 110.3450);
      if (bcLower.contains('promasan')) return const LatLng(-7.1620, 110.3340);
    }

    // ── GUNUNG GEDE (Jawa Barat - Summit: -6.7833, 106.9833) ──
    if (mLower.contains('gede')) {
      if (bcLower.contains('putri')) return const LatLng(-6.7565, 107.0022);
      if (bcLower.contains('cibodas')) return const LatLng(-6.7412, 106.9932);
    }

    // ── GUNUNG PANGRANGO (Jawa Barat - Summit: -6.7700, 106.9639) ──
    if (mLower.contains('pangrango')) {
      if (bcLower.contains('cibodas')) return const LatLng(-6.7412, 106.9932);
      if (bcLower.contains('putri')) return const LatLng(-6.7565, 107.0022);
      if (bcLower.contains('selabintana')) return const LatLng(-6.8320, 106.9680);
    }

    // ── GUNUNG CIREMAI (Jawa Barat - Summit: -6.8925, 108.4056) ──
    if (mLower.contains('ciremai')) {
      if (bcLower.contains('apuy')) return const LatLng(-6.8960, 108.3520);
      if (bcLower.contains('linggajati') || bcLower.contains('linggarjati')) return const LatLng(-6.8820, 108.4720);
      if (bcLower.contains('linggasana')) return const LatLng(-6.8920, 108.4750);
      if (bcLower.contains('palutungan')) return const LatLng(-6.9530, 108.4380);
      if (bcLower.contains('sadarahe') || bcLower.contains('trisakti')) return const LatLng(-6.8620, 108.3680);
    }

    // ── GUNUNG SEMERU (Jawa Timur - Summit: -8.1081, 112.9225) ──
    if (mLower.contains('semeru')) {
      if (bcLower.contains('ranu pane') || bcLower.contains('ranu pani')) return const LatLng(-8.0140, 112.9510);
    }

    // ── GUNUNG ARJUNO - WELIRANG (Jawa Timur - Summit: -7.7647, 112.5892) ──
    if (mLower.contains('arjuno') || mLower.contains('welirang')) {
      if (bcLower.contains('tretes')) return const LatLng(-7.6980, 112.6310);
      if (bcLower.contains('lawang')) return const LatLng(-7.8250, 112.6580);
      if (bcLower.contains('sumber brantas') || bcLower.contains('brantas')) return const LatLng(-7.7650, 112.5320);
      if (bcLower.contains('purwosari') || bcLower.contains('tambaksari')) return const LatLng(-7.7610, 112.6680);
    }

    // ── GUNUNG PENANGGUNGAN (Jawa Timur - Summit: -7.6167, 112.6333) ──
    if (mLower.contains('penanggungan')) {
      if (bcLower.contains('tamiajeng')) return const LatLng(-7.6450, 112.5980);
      if (bcLower.contains('jolotundo')) return const LatLng(-7.6180, 112.5820);
      if (bcLower.contains('kedungudi')) return const LatLng(-7.6480, 112.6250);
    }

    // ── GUNUNG RAUNG (Jawa Timur - Summit: -8.1250, 114.0450) ──
    if (mLower.contains('raung')) {
      if (bcLower.contains('kalibaru')) return const LatLng(-8.2380, 114.0050);
      if (bcLower.contains('sumberwringin') || bcLower.contains('wringin')) return const LatLng(-8.0420, 114.0280);
    }

    // ── GUNUNG ARGOPURO (Jawa Timur - Summit: -7.9664, 113.5667) ──
    if (mLower.contains('argopuro')) {
      if (bcLower.contains('baderan')) return const LatLng(-7.8880, 113.6280);
      if (bcLower.contains('bremi')) return const LatLng(-7.9120, 113.4980);
    }

    // ── GUNUNG KELUD (Jawa Timur - Summit: -7.9300, 112.3083) ──
    if (mLower.contains('kelud')) {
      if (bcLower.contains('karangrejo')) return const LatLng(-7.9350, 112.2850);
      if (bcLower.contains('tulungrejo')) return const LatLng(-7.9420, 112.2980);
    }

    // ── GUNUNG CIKURAY (Jawa Barat - Summit: -7.3217, 107.8600) ──
    if (mLower.contains('cikuray')) {
      if (bcLower.contains('pemancar') || bcLower.contains('pamancar')) return const LatLng(-7.2880, 107.8820);
      if (bcLower.contains('bayongbong') || bcLower.contains('geurot')) return const LatLng(-7.3180, 107.8180);
    }

    // ── GUNUNG GUNTUR (Jawa Barat - Summit: -7.1433, 107.8400) ──
    if (mLower.contains('guntur')) {
      if (bcLower.contains('citiis')) return const LatLng(-7.1680, 107.8680);
      if (bcLower.contains('cikahuripan')) return const LatLng(-7.1550, 107.8650);
    }

    // ── GUNUNG BURANGRANG (Jawa Barat - Summit: -6.7761, 107.5500) ──
    if (mLower.contains('burangrang')) {
      if (bcLower.contains('legok haji')) return const LatLng(-6.7580, 107.5450);
    }

    // ── GUNUNG BATUR (Bali - Summit: -8.2424, 115.3753) ──
    if (mLower.contains('batur')) {
      if (bcLower.contains('pasar agung')) return const LatLng(-8.2615, 115.3920);
    }

    // ── GUNUNG KERINCI (Sumatra - Summit: -1.6967, 101.2642) ──
    if (mLower.contains('kerinci')) {
      if (bcLower.contains('kersik')) return const LatLng(-1.7510, 101.2580);
    }

    // ── GUNUNG DEMPO (Sumsel - Summit: -4.0319, 103.1281) ──
    if (mLower.contains('dempo')) {
      if (bcLower.contains('kampung') || bcLower.contains('balai')) return const LatLng(-4.0580, 103.1480);
      if (bcLower.contains('tugu rimau')) return const LatLng(-4.0480, 103.1380);
    }

    // ── GUNUNG TALANG (Sumbar - Summit: -0.9783, 100.6792) ──
    if (mLower.contains('talang')) {
      if (bcLower.contains('batumbuk')) return const LatLng(-0.9580, 100.6820);
      if (bcLower.contains('bajanjang')) return const LatLng(-0.9920, 100.6950);
      if (bcLower.contains('seroja')) return const LatLng(-0.9720, 100.6980);
    }

    // ── GUNUNG SIBUATAN (Sumut - Summit: 2.9189, 98.4206) ──
    if (mLower.contains('sibuatan')) {
      if (bcLower.contains('pancur')) return const LatLng(2.9320, 98.4350);
    }

    // ── GUNUNG SINABUNG (Sumut - Summit: 3.1694, 98.3917) ──
    if (mLower.contains('sinabung')) {
      if (bcLower.contains('danau lau kawar') || bcLower.contains('kawar')) return const LatLng(3.1820, 98.3980);
    }

    // ── GUNUNG LEUSER (Aceh - Summit: 3.7431, 97.1558) ──
    if (mLower.contains('leuser')) {
      if (bcLower.contains('kedah')) return const LatLng(3.9780, 97.2450);
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
        final cleanName = bcName
            .replaceAll('Basecamp Resmi ', '')
            .replaceAll('Basecamp ', '')
            .trim();
        cps.add(TrailCheckpoint(
          name: 'Pos 0: $cleanName',
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

  List<TrailCheckpoint> _parseCustomCheckpoints(String jsonStr, List<LatLng> waypoints, int peakElevasi) {
    try {
      final list = TrailCheckpoint.listFromJson(jsonStr);
      if (list.isEmpty) return _generateCheckpointsFromWaypoints('Basecamp', waypoints, peakElevasi);

      final List<TrailCheckpoint> resolved = [];
      final int count = list.length;
      for (int i = 0; i < count; i++) {
        final cp = list[i];
        LatLng loc = cp.location;
        // Jika koordinat belum diisi atau 0,0, tempatkan secara berurutan sepanjang waypoints rute
        if (loc.latitude == 0.0 && loc.longitude == 0.0) {
          final t = count > 1 ? (i / (count - 1)) : 0.0;
          final int wpIndex = (t * (waypoints.length - 1)).round().clamp(0, waypoints.length - 1);
          loc = waypoints[wpIndex];
        }
        resolved.add(cp.copyWith(location: loc));
      }
      return resolved;
    } catch (e) {
      debugPrint('⚠️ Gagal parse custom checkpoints: $e');
      return _generateCheckpointsFromWaypoints('Basecamp', waypoints, peakElevasi);
    }
  }

  /// Menghasilkan template pos default untuk dijadikan acuan awal saat petugas ingin mengedit pos
  List<TrailCheckpoint> generateDefaultCheckpoints(String bcName, int peakElevasi) {
    const int count = 6;
    final List<TrailCheckpoint> cps = [];
    final int baseElevasi = max(600, (peakElevasi * 0.45).round());

    for (int i = 0; i < count; i++) {
      final t = i / (count - 1);
      final elevasi = (baseElevasi + (peakElevasi - baseElevasi) * t).round();

      if (i == 0) {
        cps.add(TrailCheckpoint(
          name: 'Pos 0: Basecamp $bcName',
          location: const LatLng(0, 0),
          elevationMdpl: elevasi,
          description: 'Pusat registrasi, verifikasi tiket simaksi & briefing keselamatan',
          hasWater: true,
        ));
      } else if (i == count - 1) {
        cps.add(TrailCheckpoint(
          name: 'Puncak Tertinggi',
          location: const LatLng(0, 0),
          elevationMdpl: peakElevasi,
          description: 'Titik puncak tertinggi dengan panorama 360 derajat',
          hasWater: false,
        ));
      } else if (i == (count / 2).round()) {
        cps.add(TrailCheckpoint(
          name: 'Pos $i: Shelter & Camp Area',
          location: const LatLng(0, 0),
          elevationMdpl: elevasi,
          description: 'Area pendirian tenda utama dan sumber mata air',
          hasWater: true,
        ));
      } else {
        cps.add(TrailCheckpoint(
          name: 'Pos $i',
          location: const LatLng(0, 0),
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
