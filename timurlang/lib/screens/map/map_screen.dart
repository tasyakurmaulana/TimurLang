// ============================================
// TimurLang - Interactive Real Map Screen
// Powered by flutter_map & OpenStreetMap / OpenTopoMap / Esri Satellite
// Menampilkan seluruh jalur resmi & basecamp untuk 46 gunung di Indonesia
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../models/basecamp_post.dart';
import '../../services/database_service.dart';
import '../../services/trail_service.dart';

enum MapLayerType {
  standard,
  topographic,
  satellite,
}

class MapScreen extends StatefulWidget {
  final Mountain? initialMountain;
  const MapScreen({super.key, this.initialMountain});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  List<Mountain> _mountains = [];
  List<BasecampPost> _allBasecamps = [];
  Mountain? _selectedMountain;
  HikingTrail? _highlightedTrail;
  bool _isLoading = true;

  MapLayerType _selectedLayer = MapLayerType.standard;

  // Layer tile configurations
  final Map<MapLayerType, Map<String, dynamic>> _layerConfigs = {
    MapLayerType.standard: {
      'name': 'Peta Standar (OSM)',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'icon': Icons.map_outlined,
    },
    MapLayerType.topographic: {
      'name': 'Topografi & Kontur',
      'url': 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      'icon': Icons.terrain_outlined,
    },
    MapLayerType.satellite: {
      'name': 'Citra Satelit Asli',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'icon': Icons.satellite_alt_outlined,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final mountains = await DatabaseService.instance.getAllMountains();
      final basecamps = await DatabaseService.instance.getAllBasecampPosts();

      if (mounted) {
        setState(() {
          _mountains = mountains;
          _allBasecamps = basecamps;
          _isLoading = false;
        });

        // Center on initial mountain if passed
        if (widget.initialMountain != null) {
          _focusMountain(widget.initialMountain!);
        } else if (_mountains.isNotEmpty) {
          _focusMountain(_mountains.first);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _focusMountain(Mountain mountain) {
    setState(() {
      _selectedMountain = mountain;
      _highlightedTrail = null;
    });
    _mapController.move(
      LatLng(mountain.koordinatLat, mountain.koordinatLong),
      12.2,
    );
  }

  List<HikingTrail> get _activeTrails {
    if (_selectedMountain == null) return [];
    return TrailService.instance.getTrailsForMountain(_selectedMountain!, _allBasecamps);
  }

  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Pilih Tampilan Peta',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...MapLayerType.values.map((type) {
                  final config = _layerConfigs[type]!;
                  final isSelected = _selectedLayer == type;
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primarySubtle : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        config['icon'] as IconData,
                        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      config['name'] as String,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedLayer = type);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMountainDetails(Mountain mountain) {
    final trails = TrailService.instance.getTrailsForMountain(mountain, _allBasecamps);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final statusColor = mountain.statusJalur == 'Buka'
            ? AppTheme.success
            : mountain.statusJalur.contains('Waspada')
                ? AppTheme.warning
                : AppTheme.error;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        mountain.namaGunung,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        mountain.statusJalur,
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoBadge(Icons.height, '${mountain.elevasiMdpl} MDPL', AppTheme.primary),
                    const SizedBox(width: 8),
                    _buildInfoBadge(
                      Icons.water_drop,
                      mountain.sumberAirTersedia ? 'Ada Air' : 'Kering',
                      mountain.sumberAirTersedia ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoBadge(Icons.alt_route, '${trails.length} Basecamp', AppTheme.secondary),
                  ],
                ),
                if (mountain.deskripsi != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    mountain.deskripsi!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _focusMountain(mountain);
                        },
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Fokus Jalur Peta'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.mountainDetail,
                            arguments: mountain,
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Detail Gunung'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBasecampDetails(HikingTrail trail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isBuka = trail.statusJalur.toLowerCase() == 'buka';
        final statusColor = isBuka ? AppTheme.success : AppTheme.error;

        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: trail.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: trail.color),
                        ),
                        child: Icon(Icons.holiday_village_outlined, color: trail.color, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trail.basecampName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Jalur Resmi ${trail.mountainName}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: trail.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          trail.statusJalur,
                          style: GoogleFonts.plusJakartaSans(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Trail metrics
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricItem(Icons.straighten, '${trail.distanceKm} km', 'Panjang Jalur'),
                        Container(width: 1, height: 30, color: AppTheme.border),
                        _metricItem(Icons.timer_outlined, '±${trail.estimatedHours} Jam', 'Estimasi Waktu'),
                        Container(width: 1, height: 30, color: AppTheme.border),
                        _metricItem(
                          Icons.confirmation_number_outlined,
                          'Rp ${trail.basecampPost.hargaSimaksi.toInt()}',
                          'Tarif SIMAKSI',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trail.basecampPost.lokasiDeskripsi,
                    style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 8),
                  Text(
                    'Titik Pos & Checkpoint Pendakian:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Checkpoint sequence
                  for (int i = 0; i < trail.checkpoints.length; i++) ...[
                    _checkpointRow(trail.checkpoints[i], i == 0, i == trail.checkpoints.length - 1, trail.color),
                  ],
                  const SizedBox(height: 24),
                  // Button Daftar SIMAKSI
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: isBuka
                          ? () {
                              Navigator.pop(ctx);
                              Navigator.pushNamed(
                                context,
                                AppRoutes.simaksiForm,
                                arguments: {
                                  'mountain': _selectedMountain,
                                  'mountainId': _selectedMountain?.id,
                                  'basecampId': trail.basecampId,
                                  'basecamp': trail.basecampPost,
                                  'basecampName': trail.basecampName,
                                },
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.assignment_turned_in, size: 20),
                      label: Text(isBuka ? 'Daftar SIMAKSI Via Jalur Ini' : 'Jalur Sedang Ditutup'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _metricItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _checkpointRow(TrailCheckpoint cp, bool isFirst, bool isLast, Color trailColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLast ? Colors.redAccent : isFirst ? trailColor : AppTheme.surface,
                  border: Border.all(color: trailColor, width: 2),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  color: trailColor.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cp.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isLast ? Colors.redAccent : AppTheme.textPrimary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cp.hasWater) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.water_drop, size: 10, color: Colors.lightBlue),
                                SizedBox(width: 2),
                                Text(
                                  'Air',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.lightBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Text(
                          '${cp.elevationMdpl} MDPL',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  cp.description,
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTileUrl = _layerConfigs[_selectedLayer]!['url']!;
    final activeTrails = _activeTrails;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peta Topografi & Jalur'),
        actions: [
          IconButton(
            tooltip: 'Ganti Lapisan Peta',
            icon: const Icon(Icons.layers),
            onPressed: _showLayerSelector,
          ),
        ],
      ),
      body: Stack(
        children: [
          // FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(-7.942, 112.953), // Bromo - Semeru region
              initialZoom: 9.5,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              // Tile Layer
              TileLayer(
                urlTemplate: activeTileUrl,
                userAgentPackageName: 'com.timurlang.app',
                maxZoom: 18,
              ),

              // Hiking Trails (Polylines)
              PolylineLayer(
                polylines: activeTrails.map((trail) {
                  final isHighlighted = _highlightedTrail?.id == trail.id;
                  return Polyline(
                    points: trail.waypoints,
                    strokeWidth: isHighlighted ? 6.0 : 4.0,
                    color: trail.color,
                  );
                }).toList(),
              ),

              // Mountain & Basecamp Markers
              MarkerLayer(
                markers: [
                  // 1. Mountain Peak Markers
                  ..._mountains.map((mountain) {
                    final isSelected = _selectedMountain?.id == mountain.id;
                    final statusColor = mountain.statusJalur == 'Buka'
                        ? AppTheme.safeGreen
                        : mountain.statusJalur.contains('Waspada')
                            ? AppTheme.warningYellow
                            : AppTheme.dangerRed;

                    return Marker(
                      point: LatLng(mountain.koordinatLat, mountain.koordinatLong),
                      width: isSelected ? 70 : 54,
                      height: isSelected ? 70 : 54,
                      child: GestureDetector(
                        onTap: () {
                          _focusMountain(mountain);
                          _showMountainDetails(mountain);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.accentOrange : AppTheme.cardDark,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : statusColor,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.terrain,
                                size: isSelected ? 24 : 18,
                                color: isSelected ? Colors.white : statusColor,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                mountain.namaGunung.replaceAll('Gunung ', ''),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // 2. Basecamp Trailhead Markers for the selected mountain
                  ...activeTrails.map((trail) {
                    final isHighlighted = _highlightedTrail?.id == trail.id;
                    return Marker(
                      point: trail.basecampLocation,
                      width: 100,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _highlightedTrail = trail);
                          _showBasecampDetails(trail);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: trail.color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.holiday_village,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isHighlighted ? trail.color : Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: trail.color, width: 1),
                              ),
                              child: Text(
                                trail.basecampName.replaceAll('Basecamp Resmi ', '').replaceAll('Desa ', ''),
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Top Mountain Selector Bar
          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _mountains.length,
                itemBuilder: (context, index) {
                  final m = _mountains[index];
                  final isSelected = _selectedMountain?.id == m.id;
                  final bcCount = _allBasecamps.where((b) => b.gunungId == m.id).length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        Icons.terrain,
                        size: 16,
                        color: isSelected ? Colors.white : AppTheme.primary,
                      ),
                      label: Text(
                        '${m.namaGunung.replaceAll('Gunung ', '')}${bcCount > 0 ? ' ($bcCount Jalur)' : ''}',
                      ),
                      backgroundColor: isSelected ? AppTheme.primary : AppTheme.surface,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12,
                      ),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      onPressed: () => _focusMountain(m),
                    ),
                  );
                },
              ),
            ),
          ),

          // Legend / Active Mountain Trail List (Bottom Left)
          if (_selectedMountain != null && activeTrails.isNotEmpty)
            Positioned(
              left: 12,
              bottom: 24,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240, maxHeight: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _selectedMountain!.namaGunung,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${activeTrails.length} Jalur',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 6),
                      for (final trail in activeTrails) ...[
                        InkWell(
                          onTap: () {
                            setState(() => _highlightedTrail = trail);
                            _showBasecampDetails(trail);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: trail.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    trail.basecampName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: _highlightedTrail?.id == trail.id ? FontWeight.bold : FontWeight.w500,
                                      color: _highlightedTrail?.id == trail.id ? trail.color : AppTheme.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${trail.distanceKm} km',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Zoom & Layer Controls (Bottom Right)
          Positioned(
            right: 12,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Layer button
                FloatingActionButton.small(
                  heroTag: 'map_layer_fab',
                  backgroundColor: AppTheme.surface,
                  elevation: 3,
                  onPressed: _showLayerSelector,
                  child: const Icon(Icons.layers_outlined, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                // Zoom in
                FloatingActionButton.small(
                  heroTag: 'zoom_in_fab',
                  backgroundColor: AppTheme.surface,
                  elevation: 3,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom + 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.add, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                // Zoom out
                FloatingActionButton.small(
                  heroTag: 'zoom_out_fab',
                  backgroundColor: AppTheme.surface,
                  elevation: 3,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.remove, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                // Re-center on selected mountain
                FloatingActionButton.small(
                  heroTag: 'center_fab',
                  backgroundColor: AppTheme.primary,
                  elevation: 3,
                  onPressed: () {
                    if (_selectedMountain != null) {
                      _focusMountain(_selectedMountain!);
                    } else {
                      _mapController.move(const LatLng(-7.942, 112.953), 9.5);
                    }
                  },
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
