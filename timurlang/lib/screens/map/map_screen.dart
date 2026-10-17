// ============================================
// TimurLang - Interactive Real Map Screen
// Powered by flutter_map & OpenStreetMap / OpenTopoMap / Esri Satellite
// 100% Free - No Mapbox API Key Required
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../services/database_service.dart';

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
  Mountain? _selectedMountain;
  bool _isLoading = true;

  MapLayerType _selectedLayer = MapLayerType.standard;

  // Layer tile configurations
  final Map<MapLayerType, Map<String, String>> _layerConfigs = {
    MapLayerType.standard: {
      'name': 'Peta Standar (OSM)',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'icon': '🗺️',
    },
    MapLayerType.topographic: {
      'name': 'Topografi & Kontur',
      'url': 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      'icon': '⛰️',
    },
    MapLayerType.satellite: {
      'name': 'Citra Satelit Asli',
      'url': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
      'icon': '🛰️',
    },
  };

  // Sample hiking trail polylines for visualization
  // Semeru: Ranu Pani (-8.014, 112.951) -> Ranu Kumbolo (-8.056, 112.923) -> Kalimati (-8.082, 112.924) -> Mahameru (-8.108, 112.922)
  final List<LatLng> _semeruTrail = const [
    LatLng(-8.014, 112.951), // Pos Ranu Pani
    LatLng(-8.028, 112.942), // Watu Rejeng
    LatLng(-8.056, 112.923), // Ranu Kumbolo
    LatLng(-8.067, 112.921), // Oro-oro Ombo
    LatLng(-8.073, 112.922), // Cemoro Kandang
    LatLng(-8.082, 112.924), // Pos Kalimati
    LatLng(-8.094, 112.923), // Arcopodo
    LatLng(-8.108, 112.922), // Puncak Mahameru
  ];

  // Bromo trail: Cemoro Lawang (-7.923, 112.964) -> Lautan Pasir -> Kawah Bromo (-7.942, 112.953)
  final List<LatLng> _bromoTrail = const [
    LatLng(-7.923, 112.964), // Cemoro Lawang
    LatLng(-7.930, 112.960), // Laut Pasir
    LatLng(-7.937, 112.957), // Pura Poten
    LatLng(-7.942, 112.953), // Kawah Bromo
  ];

  // Merbabu trail via Selo: Basecamp Selo (-7.498, 110.457) -> Pos 1 -> Pos 2 -> Sabana 1 -> Sabana 2 -> Puncak Kenteng Songo (-7.455, 110.440)
  final List<LatLng> _merbabuTrail = const [
    LatLng(-7.498, 110.457), // Basecamp Selo
    LatLng(-7.485, 110.451), // Pos 1 Dok-dok-an
    LatLng(-7.476, 110.448), // Pos 2 Pandean
    LatLng(-7.467, 110.445), // Sabana 1
    LatLng(-7.460, 110.442), // Sabana 2
    LatLng(-7.455, 110.440), // Puncak Kenteng Songo
  ];

  @override
  void initState() {
    super.initState();
    _loadMountains();
  }

  Future<void> _loadMountains() async {
    try {
      final list = await DatabaseService.instance.getAllMountains();
      if (mounted) {
        setState(() {
          _mountains = list;
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
    setState(() => _selectedMountain = mountain);
    _mapController.move(
      LatLng(mountain.koordinatLat, mountain.koordinatLong),
      12.0,
    );
  }

  void _showLayerSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
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
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Pilih Tampilan Peta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                ...MapLayerType.values.map((type) {
                  final config = _layerConfigs[type]!;
                  final isSelected = _selectedLayer == type;
                  return ListTile(
                    leading: Text(config['icon']!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      config['name']!,
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryGreen : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen)
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final statusColor = mountain.statusJalur == 'Buka'
            ? AppTheme.safeGreen
            : mountain.statusJalur.contains('Waspada')
                ? AppTheme.warningYellow
                : AppTheme.dangerRed;

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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        mountain.statusJalur,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoBadge(Icons.height, '${mountain.elevasiMdpl} MDPL', AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    _buildInfoBadge(
                      Icons.water_drop,
                      mountain.sumberAirTersedia ? 'Sumber Air: Ada' : 'Sumber Air: Kering',
                      mountain.sumberAirTersedia ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoBadge(Icons.warning_amber, mountain.tingkatBahaya, AppTheme.accentOrange),
                  ],
                ),
                if (mountain.deskripsi != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    mountain.deskripsi!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                        label: const Text('Fokus Peta'),
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
                        label: const Text('Detail Jalur'),
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
                polylines: [
                  Polyline(
                    points: _semeruTrail,
                    strokeWidth: 4.0,
                    color: Colors.redAccent,
                  ),
                  Polyline(
                    points: _bromoTrail,
                    strokeWidth: 4.0,
                    color: Colors.orangeAccent,
                  ),
                  Polyline(
                    points: _merbabuTrail,
                    strokeWidth: 4.0,
                    color: AppTheme.primaryGreen,
                  ),
                ],
              ),

              // Mountain Markers
              MarkerLayer(
                markers: _mountains.map((mountain) {
                  final isSelected = _selectedMountain?.id == mountain.id;
                  final statusColor = mountain.statusJalur == 'Buka'
                      ? AppTheme.safeGreen
                      : mountain.statusJalur.contains('Waspada')
                          ? AppTheme.warningYellow
                          : AppTheme.dangerRed;

                  return Marker(
                    point: LatLng(mountain.koordinatLat, mountain.koordinatLong),
                    width: isSelected ? 65 : 50,
                    height: isSelected ? 65 : 50,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedMountain = mountain);
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
                }).toList(),
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
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        Icons.terrain,
                        size: 16,
                        color: isSelected ? Colors.white : AppTheme.primaryGreen,
                      ),
                      label: Text(m.namaGunung.replaceAll('Gunung ', '')),
                      backgroundColor: isSelected ? AppTheme.primaryGreen : AppTheme.cardDark.withValues(alpha: 0.9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryGreen : Colors.white24,
                        ),
                      ),
                      onPressed: () => _focusMountain(m),
                    ),
                  );
                },
              ),
            ),
          ),

          // Legend / Trail Info Box (Bottom Left)
          Positioned(
            left: 12,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _layerConfigs[_selectedLayer]!['name']!,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 3, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      const Text('Jalur Semeru', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 3, color: Colors.orangeAccent),
                      const SizedBox(width: 6),
                      const Text('Jalur Bromo', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 3, color: AppTheme.primaryGreen),
                      const SizedBox(width: 6),
                      const Text('Jalur Merbabu', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    ],
                  ),
                ],
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
                  backgroundColor: AppTheme.cardDark,
                  onPressed: _showLayerSelector,
                  child: const Icon(Icons.layers, color: Colors.white),
                ),
                const SizedBox(height: 8),
                // Zoom in
                FloatingActionButton.small(
                  heroTag: 'zoom_in_fab',
                  backgroundColor: AppTheme.cardDark,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom + 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(height: 8),
                // Zoom out
                FloatingActionButton.small(
                  heroTag: 'zoom_out_fab',
                  backgroundColor: AppTheme.cardDark,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom - 1;
                    _mapController.move(_mapController.camera.center, zoom);
                  },
                  child: const Icon(Icons.remove, color: Colors.white),
                ),
                const SizedBox(height: 8),
                // Re-center on selected mountain or center of Java
                FloatingActionButton.small(
                  heroTag: 'center_fab',
                  backgroundColor: AppTheme.primaryGreen,
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
