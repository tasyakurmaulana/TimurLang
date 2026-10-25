// ============================================
// TimurLang - Mountain Detail Screen
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../models/basecamp_post.dart';
import '../../services/database_service.dart';
import '../../services/weather_service.dart';
import '../../utils/image_helper.dart';

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

  bool _isLoadingMountain = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Mountain) {
      _mountain = args;
      _loadData();
    } else if (args is String) {
      _loadMountainById(args);
    } else if (args != null) {
      _loadMountainById(args.toString());
    }
  }

  Future<void> _loadMountainById(String id) async {
    setState(() => _isLoadingMountain = true);
    try {
      final mountain = await DatabaseService.instance.getMountainById(id);
      if (mounted) {
        setState(() {
          _mountain = mountain;
          _isLoadingMountain = false;
        });
        if (_mountain != null) {
          _loadData();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMountain = false);
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
      if (_isLoadingMountain) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Data gunung tidak ditemukan')),
      );
    }

    final m = _mountain!;
    final imageProvider = ImageHelper.getImageProvider(m.fotoUrl, m.namaGunung) ??
        const AssetImage('assets/images/background_mount.png') as ImageProvider;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header with real mountain photo
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 1,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(gradient: AppTheme.mountainGradient),
                      child: const Center(
                        child: Icon(Icons.terrain, size: 64, color: Colors.white54),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${m.elevasiMdpl} MDPL',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m.namaGunung,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                      if (m.sumberAirTersedia) ...[
                        const SizedBox(width: 8),
                        _badge(
                          'Air',
                          AppTheme.skyBlue,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (m.deskripsi != null) ...[
                    const Text('Deskripsi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      m.deskripsi!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Coordinates
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.secondary, size: 20),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Koordinat', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text(
                              '${m.koordinatLat}°, ${m.koordinatLong}°',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (m.kuotaHarian != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Kuota Harian', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Text(
                                '${m.kuotaHarian} orang',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Weather
                  const Text('Cuaca Terkini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  _loadingWeather
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : _weather != null
                          ? _buildWeatherCard()
                          : const Text('Data cuaca tidak tersedia', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 20),

                  // Basecamps
                  const Text('Pos Pendakian & Basecamp Jalur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  ..._basecamps.map((bc) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: bc.isBuka ? AppTheme.border : AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              bc.isBuka ? Icons.house : Icons.cancel_outlined,
                              color: bc.isBuka ? AppTheme.primary : AppTheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(bc.namaPos, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (bc.isBuka ? AppTheme.success : AppTheme.error).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                bc.isBuka ? 'Jalur Buka' : 'Jalur Tutup',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: bc.isBuka ? AppTheme.success : AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bc.lokasiDeskripsi,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.people_outline, size: 14, color: AppTheme.secondary),
                            const SizedBox(width: 4),
                            Text(
                              'Sisa Kuota: ${bc.sisaKuotaHariIni} / ${bc.kuotaHarian} orang',
                              style: const TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            const Icon(Icons.payments_outlined, size: 14, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Rp ${bc.hargaSimaksi.toInt()}/hr',
                              style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.confirmation_num),
                      label: Text(
                        m.statusJalur == 'Tutup'
                            ? 'Jalur Ditutup'
                            : 'Booking Simaksi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: w.isStormWarning ? AppTheme.error : AppTheme.border),
      ),
      child: Column(
        children: [
          if (w.isStormWarning)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PERINGATAN BADAI - Tunda pendakian!',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.error),
              ),
            ),
          Row(
            children: [
              Text(w.icon, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${w.temperature}°C', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  Text(w.condition, style: const TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Angin: ${w.windSpeed.toStringAsFixed(1)} km/h', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  Text('Lembap: ${w.humidity.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
