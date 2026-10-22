// ============================================
// TimurLang - Mountain Detail Screen
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../models/basecamp_post.dart';
import '../../services/database_service.dart';
import '../../services/weather_service.dart';

class MountainDetailScreen extends StatefulWidget {
  const MountainDetailScreen({super.key});

  @override
  State<MountainDetailScreen> createState() => _MountainDetailScreenState();
}

class _MountainDetailScreenState extends State<MountainDetailScreen> {
  Mountain? _mountain;
  List<BasecampPost> _basecamps = [];
  WeatherData? _weather;
  bool _loadingWeather = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mountain = ModalRoute.of(context)?.settings.arguments as Mountain?;
    if (_mountain != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final basecamps = await DatabaseService.instance.getBasecampsByMountain(_mountain!.id);
      final weather = await WeatherService.instance.getCurrentWeather(
        _mountain!.koordinatLat,
        _mountain!.koordinatLong,
      );
      if (mounted) {
        setState(() {
          _basecamps = basecamps;
          _weather = weather;
          _loadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mountain == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Data gunung tidak ditemukan')),
      );
    }

    final m = _mountain!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                m.namaGunung,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.mountainGradient),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.terrain, size: 60, color: Colors.white54),
                      const SizedBox(height: 8),
                      Text(
                        '${m.elevasiMdpl} mdpl',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & grade badges
                  Row(
                    children: [
                      _badge(m.statusJalur, _getStatusColor(m.statusJalur)),
                      const SizedBox(width: 8),
                      _badge(m.tingkatBahaya, AppTheme.accentOrange),
                      const SizedBox(width: 8),
                      _badge(
                        m.sumberAirTersedia ? '💧 Air Tersedia' : '❌ Tanpa Air',
                        m.sumberAirTersedia ? AppTheme.skyBlue : AppTheme.mistGrey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (m.deskripsi != null) ...[
                    const Text('Deskripsi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      m.deskripsi!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Coordinates
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.accentOrange, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Koordinat', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                            Text(
                              '${m.koordinatLat}°, ${m.koordinatLong}°',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (m.kuotaHarian != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Kuota Harian', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                              Text(
                                '${m.kuotaHarian} orang',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Weather
                  const Text('Cuaca Terkini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _loadingWeather
                      ? const Center(child: CircularProgressIndicator())
                      : _weather != null
                          ? _buildWeatherCard()
                          : Text('Data cuaca tidak tersedia', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(height: 20),

                  // Basecamps
                  const Text('Pos Pendakian & Basecamp Jalur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._basecamps.map((bc) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bc.isBuka ? Colors.white12 : AppTheme.dangerRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              bc.isBuka ? Icons.house : Icons.cancel_outlined,
                              color: bc.isBuka ? AppTheme.primaryGreen : AppTheme.dangerRed,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(bc.namaPos, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (bc.isBuka ? AppTheme.safeGreen : AppTheme.dangerRed).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                bc.isBuka ? 'Jalur Buka' : 'Jalur Tutup',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: bc.isBuka ? AppTheme.safeGreen : AppTheme.dangerRed,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bc.lokasiDeskripsi,
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 14, color: AppTheme.accentOrange),
                            const SizedBox(width: 4),
                            Text(
                              'Sisa Kuota: ${bc.sisaKuotaHariIni} / ${bc.kuotaHarian} orang',
                              style: const TextStyle(fontSize: 11, color: AppTheme.accentOrange, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Icon(Icons.payments_outlined, size: 14, color: AppTheme.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              'Rp ${bc.hargaSimaksi.toInt()}/hr',
                              style: const TextStyle(fontSize: 11, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 24),

                  // Book button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: m.statusJalur == 'Tutup'
                          ? null
                          : () => Navigator.pushNamed(
                                context,
                                AppRoutes.simaksiForm,
                                arguments: m,
                              ),
                      icon: const Icon(Icons.confirmation_num),
                      label: Text(
                        m.statusJalur == 'Tutup'
                            ? 'Jalur Ditutup'
                            : 'Booking Simaksi',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    final w = _weather!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: w.isStormWarning ? AppTheme.dangerGradient : AppTheme.darkCardGradient,
        borderRadius: BorderRadius.circular(12),
        border: w.isStormWarning ? null : Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          if (w.isStormWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ PERINGATAN BADAI - Tunda pendakian!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          Row(
            children: [
              Text(w.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${w.temperature}°C', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text(w.condition, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('💨 ${w.windSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 12)),
                  Text('💧 ${w.humidity.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Buka': return AppTheme.safeGreen;
      case 'Tutup': return AppTheme.dangerRed;
      default: return AppTheme.warningYellow;
    }
  }
}
