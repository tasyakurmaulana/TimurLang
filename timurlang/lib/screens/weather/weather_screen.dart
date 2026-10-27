// ============================================
// TimurLang - Weather Screen (Clean Atmosphere UI)
// ============================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  WeatherData? _currentWeather;
  List<WeatherForecast> _forecast = [];
  List<HourlyForecast> _hourlyForecast = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCity;
  double? _selectedLat;
  double? _selectedLon;
  final TextEditingController _searchCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Controller untuk Card Carousel 4 Seputar Cuaca
  final PageController _carouselCtrl = PageController();
  int _carouselIndex = 0;

  // Daftar gunung populer Indonesia untuk quick selector
  final List<Map<String, dynamic>> _popularMountains = [
    {'name': 'Gunung Rinjani', 'query': 'Sembalun', 'lat': -8.4200, 'lon': 116.4580},
    {'name': 'Gunung Semeru', 'query': 'Lumajang', 'lat': -8.1077, 'lon': 112.9224},
    {'name': 'Gunung Merbabu', 'query': 'Selo', 'lat': -7.4550, 'lon': 110.4400},
    {'name': 'Gunung Bromo', 'query': 'Probolinggo', 'lat': -7.9425, 'lon': 112.9530},
    {'name': 'Gunung Prau', 'query': 'Dieng', 'lat': -7.1866, 'lon': 109.9190},
    {'name': 'Gunung Gede', 'query': 'Cianjur', 'lat': -6.7844, 'lon': 106.9825},
    {'name': 'Gunung Kerinci', 'query': 'Kerinci', 'lat': -1.6970, 'lon': 101.2640},
    {'name': 'Gunung Slamet', 'query': 'Bambangan', 'lat': -7.2425, 'lon': 109.2080},
    {'name': 'Gunung Lawu', 'query': 'Karanganyar', 'lat': -7.6258, 'lon': 111.1925},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadWeather();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _carouselCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Buka website OpenWeatherMap untuk prakiraan 48 jam atau 15 hari
  Future<void> _openOpenWeatherWeb({bool is15Days = false}) async {
    final query = _selectedCity ?? _currentWeather?.locationName ?? 'Indonesia';
    final lat = _selectedLat ?? _currentWeather?.latitude;
    final lon = _selectedLon ?? _currentWeather?.longitude;

    Uri url;
    if (lat != null && lon != null && lat != 0 && lon != 0) {
      url = Uri.parse(
        'https://openweathermap.org/weathermap?basemap=map&cities=true&layer=precipitation&lat=$lat&lon=$lon&zoom=10',
      );
    } else {
      url = Uri.parse('https://openweathermap.org/find?q=${Uri.encodeComponent(query)}');
    }

    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka browser: ${url.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadWeather({String? cityName, double? lat, double? lon}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (cityName != null) {
        _selectedCity = cityName;
        _searchCtrl.text = cityName;
      }
      _selectedLat = lat;
      _selectedLon = lon;
    });

    try {
      WeatherData current;
      List<WeatherForecast> forecast;
      List<HourlyForecast> hourly;

      if (lat != null && lon != null) {
        current = await WeatherService.instance.getCurrentWeather(lat, lon);
        forecast = await WeatherService.instance.getForecast(lat, lon);
        hourly = await WeatherService.instance.getHourlyForecast(lat, lon);
      } else if (_selectedCity != null) {
        current = await WeatherService.instance.getWeatherByCity(_selectedCity!);
        forecast = await WeatherService.instance.getForecastByCity(_selectedCity!);
        hourly = await WeatherService.instance.getHourlyForecastByCity(_selectedCity!);
      } else {
        current = await WeatherService.instance.getCurrentWeather(null, null);
        forecast = await WeatherService.instance.getForecast(null, null);
        hourly = await WeatherService.instance.getHourlyForecast(null, null);
      }

      if (mounted) {
        setState(() {
          _currentWeather = current;
          _forecast = forecast;
          _hourlyForecast = hourly;
          _isLoading = false;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// Dialog pemilihan dan pencarian lokasi real-time (Bebas overflow saat keyboard muncul)
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: EdgeInsets.only(
              top: 18,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFA1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pilih Lokasi Cuaca',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Cari kota atau gunung...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8)),
                        onPressed: () {
                          final text = _searchCtrl.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(ctx);
                            _loadWeather(cityName: text);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        Navigator.pop(ctx);
                        _loadWeather(cityName: val.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Tombol GPS Saya
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedCity = null;
                        _selectedLat = null;
                        _selectedLon = null;
                      });
                      _searchCtrl.clear();
                      _loadWeather();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gunakan Lokasi GPS Saya',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Deteksi akurat koordinat satelit ponsel saat ini',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  Text(
                    'Gunung Populer',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularMountains.map((m) {
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _loadWeather(
                            cityName: m['name'] as String,
                            lat: m['lat'] as double?,
                            lon: m['lon'] as double?,
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.landscape_rounded, size: 14, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Text(
                                m['name'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBaseBackgroundColor(),
      body: Stack(
        children: [
          // 1. Clean Atmospheric Background (Gradien dinamis menyesuaikan cuaca & waktu)
          Positioned.fill(
            child: _buildCleanAtmosphereBackground(),
          ),

          // 2. Weather Illustration Background (Mepet atas saja, lebarnya dan tingginya sesuai gambar asli)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Image.asset(
                  _getWeatherBackgroundImage(),
                  key: ValueKey(_getWeatherBackgroundImage()),
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBaseBackgroundColor() {
    return _getAtmosphereGradientColors().last;
  }

  String _getWeatherBackgroundImage() {
    final now = DateTime.now();
    final hour = now.hour;
    final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;
    final isNight = (_currentWeather != null && _currentWeather!.sunrise > 0 && _currentWeather!.sunset > 0)
        ? (nowEpoch < _currentWeather!.sunrise || nowEpoch >= _currentWeather!.sunset)
        : (hour < 6 || hour >= 18);

    final condition = _currentWeather?.condition.toLowerCase() ?? '';
    final description = _currentWeather?.description.toLowerCase() ?? '';

    final isRain = condition.contains('hujan') ||
        condition.contains('gerimis') ||
        condition.contains('badai') ||
        condition.contains('petir') ||
        condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunderstorm') ||
        description.contains('hujan') ||
        description.contains('gerimis') ||
        description.contains('badai') ||
        (_currentWeather?.isStormWarning ?? false) ||
        ((_currentWeather?.rain1h ?? 0) > 0);

    if (isRain) {
      return 'assets/images/weather_hujan.png';
    }

    final isClouds = condition.contains('awan') ||
        condition.contains('mendung') ||
        condition.contains('kabut') ||
        condition.contains('cloud') ||
        condition.contains('mist') ||
        condition.contains('fog') ||
        condition.contains('haze') ||
        description.contains('awan') ||
        description.contains('mendung') ||
        description.contains('kabut');

    if (isClouds) {
      return 'assets/images/weather_berawan.png';
    }

    if (isNight || condition.contains('malam') || description.contains('malam')) {
      return 'assets/images/weather_malam.png';
    }

    return 'assets/images/weather_cerah.png';
  }

  List<Color> _getAtmosphereGradientColors() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    final timeInMinutes = hour * 60 + minute;
    final nowEpoch = now.millisecondsSinceEpoch ~/ 1000;

    final isMorning = timeInMinutes >= 300 && timeInMinutes < 510;
    final isDusk = timeInMinutes >= 930 && timeInMinutes < 1095;
    final isNight = (_currentWeather != null && _currentWeather!.sunrise > 0 && _currentWeather!.sunset > 0)
        ? (nowEpoch < _currentWeather!.sunrise || nowEpoch >= _currentWeather!.sunset)
        : (timeInMinutes >= 1095 || timeInMinutes < 300);

    final condition = _currentWeather?.condition.toLowerCase() ?? '';
    final description = _currentWeather?.description.toLowerCase() ?? '';

    final isRain = condition.contains('hujan') ||
        condition.contains('gerimis') ||
        condition.contains('badai') ||
        condition.contains('petir') ||
        condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunderstorm') ||
        description.contains('hujan') ||
        description.contains('gerimis') ||
        description.contains('badai') ||
        (_currentWeather?.isStormWarning ?? false) ||
        ((_currentWeather?.rain1h ?? 0) > 0);

    final isClouds = condition.contains('awan') ||
        condition.contains('mendung') ||
        condition.contains('kabut') ||
        condition.contains('cloud') ||
        condition.contains('mist') ||
        condition.contains('fog') ||
        condition.contains('haze') ||
        description.contains('awan') ||
        description.contains('mendung') ||
        description.contains('kabut');

    if (isRain) {
      if (isDusk) {
        return const [
          Color(0xFF2E273D),
          Color(0xFF1B1626),
          Color(0xFF0C0914),
        ];
      } else if (isNight) {
        return const [
          Color(0xFF111927),
          Color(0xFF0A0F1A),
          Color(0xFF02050A),
        ];
      } else {
        return const [
          Color(0xFF263545),
          Color(0xFF142130),
          Color(0xFF0A121C),
        ];
      }
    }

    if (isClouds) {
      if (isMorning) {
        return const [
          Color(0xFF3B5066),
          Color(0xFF233242),
          Color(0xFF101B26),
        ];
      } else if (isDusk) {
        return const [
          Color(0xFF382E47),
          Color(0xFF221A30),
          Color(0xFF0F0B18),
        ];
      } else if (isNight) {
        return const [
          Color(0xFF141C2B),
          Color(0xFF0A0F1A),
          Color(0xFF03050B),
        ];
      } else {
        return const [
          Color(0xFF2B3D52),
          Color(0xFF1B2836),
          Color(0xFF0D1620),
        ];
      }
    }

    if (isNight || condition.contains('malam') || description.contains('malam')) {
      if (hour >= 22 || hour < 5) {
        return const [
          Color(0xFF080D1A),
          Color(0xFF040710),
          Color(0xFF010206),
        ];
      } else {
        return const [
          Color(0xFF0F172A),
          Color(0xFF090E1F),
          Color(0xFF03050B),
        ];
      }
    }

    if (isMorning) {
      return const [
        Color(0xFF0284C7),
        Color(0xFF0369A1),
        Color(0xFF082F49),
      ];
    } else if (isDusk) {
      return const [
        Color(0xFFB45309),
        Color(0xFF6B21A8),
        Color(0xFF181024),
      ];
    } else {
      return const [
        Color(0xFF0284C7),
        Color(0xFF0369A1),
        Color(0xFF0B3B60),
      ];
    }
  }

  Widget _buildCleanAtmosphereBackground() {
    final gradientColors = _getAtmosphereGradientColors();
    final now = DateTime.now();
    final hour = now.hour;
    final isNight = hour < 6 || hour >= 18;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.7),
            radius: 1.1,
            colors: [
              Colors.white.withValues(alpha: isNight ? 0.04 : 0.12),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 3),
                  const SizedBox(height: 18),
                  Text(
                    'Sinkronisasi Satelit OpenWeather...',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mengambil data cuaca real-time & GPS',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _loadWeather(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final weather = _currentWeather!;

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: () => _loadWeather(),
        color: Colors.white,
        backgroundColor: const Color(0xFF1E293B),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Tombol Back di Pojok Kiri Atas
              _buildBackButton(),

              // 2. Lokasi di Bawah Tombol Back (Bisa ditekan untuk ganti lokasi)
              _buildLocationUnderBack(weather),
              const SizedBox(height: 10),

              // 3. Hero Weather (Suhu besar 32°, kondisi, ↑ max / ↓ min, terasa)
              _buildHeroWeather(weather),
              const SizedBox(height: 24),

              // 4. Card Ringkasan & Grafik Jam (Hourly Curve Chart)
              _buildHourlyForecastCard(weather),
              const SizedBox(height: 14),

              // 5. Card Carousel 4 Seputar Cuaca (Hujan Segera, Suhu Besok, Ramalan Besok, Matahari)
              _buildWeatherInfoCarousel(weather),
              const SizedBox(height: 14),

              // 6. Card Prakiraan Mingguan (7-Day Forecast dengan tombol ke OpenWeather)
              _buildDailyForecastCard(weather),
              const SizedBox(height: 14),

              // 7. Status Keamanan Pendakian (Versi Awal yang komprehensif)
              _buildHikingSafetyCard(weather),
              const SizedBox(height: 14),

              // 8. Parameter Detail Atmosfer Jalur
              _buildMetricsGrid(weather),
              const SizedBox(height: 20),

              // Info Sumber Data
              Center(
                child: Text(
                  'Data Satelit OpenWeatherMap (${DateFormat('HH:mm').format(weather.stationTime)} WIB) • Sync: ${DateFormat('HH:mm').format(weather.lastUpdated)} WIB',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  /// Tombol Back di paling atas
  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Kembali',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Perbarui Data Cuaca',
            onPressed: () => _loadWeather(),
          ),
        ],
      ),
    );
  }

  /// Lokasi di bawah tombol back (Dapat diklik untuk memilih lokasi)
  Widget _buildLocationUnderBack(WeatherData weather) {
    return InkWell(
      onTap: _showLocationPicker,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on_outlined, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _selectedCity ?? weather.locationName,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }

  /// Hero Section (Suhu Besar, Kondisi, Rentang & Terasa)
  Widget _buildHeroWeather(WeatherData weather) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${weather.temperature.round()}°',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 84,
              fontWeight: FontWeight.w300,
              height: 1.0,
              letterSpacing: -2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            weather.condition,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Text(
            '↑ ${weather.tempMax.round()}° / ↓ ${weather.tempMin.round()}°',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),

          Text(
            'Terasa seperti ${weather.feelsLike.round()}°',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card Ringkasan & Prakiraan Jam (Hourly Curve Chart)
  Widget _buildHourlyForecastCard(WeatherData weather) {
    final minT = weather.tempMin.round();
    final maxT = weather.tempMax.round();

    return _buildFrostedContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              '${weather.condition}. Tinggi $maxT - ${maxT + 2}°C & rendah ${minT - 1} - $minT°C',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),

          SizedBox(
            height: 175,
            child: _hourlyForecast.isEmpty
                ? Center(
                    child: Text(
                      'Prakiraan jam sedang disinkronkan...',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 13),
                    ),
                  )
                : _buildHourlyChartList(),
          ),

          const Divider(color: Colors.white12, height: 1),

          InkWell(
            onTap: () => _openOpenWeatherWeb(is15Days: false),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Prakiraan cuaca 48 jam',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChartList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: _hourlyForecast.length,
      itemBuilder: (context, i) {
        final item = _hourlyForecast[i];
        final timeStr = DateFormat('HH.00').format(item.time);
        final popPercent = (item.pop * 100).round();

        final prevTemp = i > 0 ? _hourlyForecast[i - 1].temperature : item.temperature;
        final nextTemp = i < _hourlyForecast.length - 1 ? _hourlyForecast[i + 1].temperature : item.temperature;

        return SizedBox(
          width: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeStr,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                item.icon,
                style: const TextStyle(fontSize: 20),
              ),
              Text(
                '${item.temperature.round()}°',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: 38,
                width: 58,
                child: CustomPaint(
                  painter: _HourlyCurveSegmentPainter(
                    prevTemp: prevTemp,
                    currTemp: item.temperature,
                    nextTemp: nextTemp,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.water_drop_rounded, size: 10, color: Color(0xFF67E8F9)),
                  const SizedBox(width: 2),
                  Text(
                    '$popPercent%',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  /// Card Carousel 4 Seputar Cuaca (Hujan Segera, Suhu Besok, Ramalan Besok, Matahari)
  Widget _buildWeatherInfoCarousel(WeatherData weather) {
    final now = DateTime.now();

    final firstRain = _hourlyForecast.firstWhere(
      (h) => h.pop > 0.25,
      orElse: () => _hourlyForecast.isNotEmpty ? _hourlyForecast.first : HourlyForecast(
        time: now.add(const Duration(hours: 3)),
        temperature: weather.temperature,
        condition: weather.condition,
        icon: weather.icon,
        pop: 0.42,
      ),
    );
    final rainDayName = DateFormat('EEEE', 'id_ID').format(firstRain.time);
    final rainPopPercent = (firstRain.pop * 100).round();
    final rainCardText = rainPopPercent > 20
        ? 'Mungkin turun hujan pada $rainDayName ${DateFormat('HH.mm').format(firstRain.time)} ($rainPopPercent%)'
        : 'Peluang hujan rendah ($rainPopPercent%). Kondisi langit relatif aman.';

    final tomorrowMax = _forecast.isNotEmpty ? _forecast.first.tempMax.round() : (weather.tempMax + 1).round();
    final tomorrowHumidity = _forecast.isNotEmpty ? _forecast.first.humidity.round() : weather.humidity.round();
    final feelsLikeTomorrow = tomorrowMax + (tomorrowHumidity > 70 ? 3 : 1);
    final feelsLikeText = 'Kelembapan $tomorrowHumidity% membuat suhu tinggi terasa spt $feelsLikeTomorrow°C';

    final tomorrowCond = _forecast.isNotEmpty ? _forecast.first.condition : 'Kemungkinan Hujan Curah';
    final forecastCardText = '$tomorrowCond besok. Tinggi $tomorrowMax derajat celcius';

    DateTime sunriseTime;
    DateTime sunsetTime;
    if (weather.sunrise > 0 && weather.sunset > 0) {
      sunriseTime = DateTime.fromMillisecondsSinceEpoch(weather.sunrise * 1000);
      sunsetTime = DateTime.fromMillisecondsSinceEpoch(weather.sunset * 1000);
    } else {
      sunriseTime = DateTime(now.year, now.month, now.day, 5, 45);
      sunsetTime = DateTime(now.year, now.month, now.day, 17, 32);
    }
    final isAfterSunset = now.isAfter(sunsetTime) || now.isBefore(sunriseTime);
    final sunTimeFormat = isAfterSunset
        ? DateFormat('HH.mm').format(sunriseTime)
        : DateFormat('HH.mm').format(sunsetTime);
    final sunTitle = isAfterSunset ? 'Matahari Telah Terbenam' : 'Jangan Lewatkan Matahari';
    final sunText = isAfterSunset
        ? 'Matahari akan terbit esok pukul $sunTimeFormat'
        : 'Matahari akan terbenam pukul $sunTimeFormat';

    double sunProgress = 0.5;
    if (now.isBefore(sunriseTime)) {
      sunProgress = 0.0;
    } else if (now.isAfter(sunsetTime)) {
      sunProgress = 1.0;
    } else {
      final totalMinutes = sunsetTime.difference(sunriseTime).inMinutes;
      final elapsed = now.difference(sunriseTime).inMinutes;
      if (totalMinutes > 0) {
        sunProgress = (elapsed / totalMinutes).clamp(0.0, 1.0);
      }
    }

    return _buildFrostedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        children: [
          SizedBox(
            height: 82,
            child: PageView(
              controller: _carouselCtrl,
              onPageChanged: (idx) => setState(() => _carouselIndex = idx),
              children: [
                _buildCarouselSlide(
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF67E8F9),
                  title: 'Hujan segera turun',
                  description: rainCardText,
                ),
                _buildCarouselSlide(
                  icon: Icons.thermostat_rounded,
                  iconColor: const Color(0xFFFB923C),
                  title: 'Suhu Besok Terasa Seperti',
                  description: feelsLikeText,
                ),
                _buildCarouselSlide(
                  icon: Icons.wb_cloudy_rounded,
                  iconColor: const Color(0xFF93C5FD),
                  title: 'Ramalan Besok',
                  description: forecastCardText,
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildCarouselSlide(
                        icon: Icons.wb_sunny_rounded,
                        iconColor: const Color(0xFFFDE047),
                        title: sunTitle,
                        description: sunText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 45,
                            width: 90,
                            child: CustomPaint(
                              painter: _SunArcPainter(progress: sunProgress),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sunTimeFormat,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final active = index == _carouselIndex;
              return GestureDetector(
                onTap: () {
                  _carouselCtrl.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 16 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselSlide({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Card Prakiraan Mingguan (7 Hari) dengan link ke OpenWeatherMap
  Widget _buildDailyForecastCard(WeatherData weather) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> dailyList = [];

    final yesterdayTempMax = (weather.tempMax + 1).round();
    final yesterdayTempMin = (weather.tempMin + 1).round();
    dailyList.add({
      'day': 'Kemarin',
      'pop': 0.05,
      'icons': ['🌤️'],
      'max': yesterdayTempMax,
      'min': yesterdayTempMin,
      'isPast': true,
    });

    dailyList.add({
      'day': 'Hari ini',
      'pop': (_hourlyForecast.isNotEmpty ? _hourlyForecast.first.pop : 0.08),
      'icons': [weather.icon, '🌦️'],
      'max': weather.tempMax.round(),
      'min': weather.tempMin.round(),
      'isPast': false,
    });

    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    if (_forecast.isNotEmpty) {
      for (final f in _forecast) {
        final dayName = dayNames[f.date.weekday - 1];
        dailyList.add({
          'day': dayName,
          'pop': f.pop,
          'icons': [f.icon, f.pop > 0.4 ? '🌧️' : '⛅'],
          'max': f.tempMax.round(),
          'min': f.tempMin.round(),
          'isPast': false,
        });
      }
    } else {
      for (int i = 1; i <= 6; i++) {
        final targetDate = now.add(Duration(days: i));
        final dayName = dayNames[targetDate.weekday - 1];
        dailyList.add({
          'day': dayName,
          'pop': (0.3 + (i * 0.08)) % 0.8,
          'icons': ['⛅', '🌦️'],
          'max': (weather.tempMax - (i % 2)).round(),
          'min': (weather.tempMin - (i % 3)).round(),
          'isPast': false,
        });
      }
    }

    return _buildFrostedContainer(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              children: dailyList.map((item) {
                final isPast = item['isPast'] as bool;
                final popPercent = ((item['pop'] as double) * 100).round();
                final icons = item['icons'] as List<dynamic>;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          item['day'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            color: isPast ? Colors.white60 : Colors.white,
                            fontSize: 14,
                            fontWeight: isPast ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: !isPast && popPercent > 0
                            ? Row(
                                children: [
                                  const Icon(Icons.water_drop_rounded, size: 12, color: Color(0xFF67E8F9)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$popPercent%',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: icons.map((ic) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(ic.toString(), style: const TextStyle(fontSize: 16)),
                        )).toList(),
                      ),
                      const Spacer(),
                      Text(
                        '${item['max']}°  ${item['min']}°',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          InkWell(
            onTap: () => _openOpenWeatherWeb(is15Days: true),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Prakiraan cuaca 15 hari',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Status Keamanan Pendakian (Versi Awal Komprehensif)
  /// Card Status Keamanan Pendakian (Identik dengan foto referensi versi Pendakian)
  Widget _buildHikingSafetyCard(WeatherData weather) {
    final condition = weather.condition.toLowerCase();
    final isStormOrRain = weather.isStormWarning ||
        condition.contains('hujan') ||
        condition.contains('badai') ||
        weather.windSpeed > 30;

    final statusText = isStormOrRain ? 'Buruk' : (weather.windSpeed > 22 ? 'Waspada' : 'Baik');
    final descText = isStormOrRain
        ? 'Cuaca Buruk untuk mendaki sekarang'
        : (weather.windSpeed > 22
            ? 'Cuaca Berangin untuk mendaki sekarang'
            : 'Cuaca Baik untuk mendaki sekarang');

    final nowHour = DateTime.now().hour;

    return _buildFrostedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul: Pendakian (seperti contoh foto "Lari")
          Text(
            'Pendakian',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom Kiri: Ikon Pendaki, Status Besar ("Buruk" / "Baik"), Deskripsi
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.hiking_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Kolom Kanan: 3 Slot Jam Berjejer (Waktu, Lingkaran Emoji Muka, Teks Status)
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (i) {
                    final targetHour = (nowHour + i + 1) % 24;
                    final hourStr = '${targetHour.toString().padLeft(2, '0')}.00';
                    final slotIsBad = isStormOrRain || (i == 1 && condition.contains('gerimis'));

                    return Column(
                      children: [
                        // Waktu jam (22.00)
                        Text(
                          hourStr,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Lingkaran Emoji Wajah (Merah/Oranye Buruk atau Hijau Baik)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: slotIsBad ? const Color(0xFFEA580C) : const Color(0xFF10B981),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              slotIsBad
                                  ? Icons.sentiment_dissatisfied_rounded
                                  : Icons.sentiment_satisfied_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Teks status di bawah emoji ("Buruk" / "Baik")
                        Text(
                          slotIsBad ? 'Buruk' : 'Baik',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Parameter Fisik Atmosfer
  Widget _buildMetricsGrid(WeatherData weather) {
    return _buildFrostedContainer(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kondisi Atmosfer Jalur',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricItem(
                icon: Icons.water_drop_outlined,
                label: 'Kelembapan',
                value: '${weather.humidity.round()}%',
              ),
              _buildMetricItem(
                icon: Icons.air_rounded,
                label: 'Kecepatan Angin',
                value: '${weather.windSpeed.toStringAsFixed(1)} km/j',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetricItem(
                icon: Icons.speed_rounded,
                label: 'Tekanan Udara',
                value: '${weather.pressure.round()} hPa',
              ),
              _buildMetricItem(
                icon: Icons.visibility_outlined,
                label: 'Jarak Pandang',
                value: '${(weather.visibility / 1000).toStringAsFixed(1)} km',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(color: Colors.white60, fontSize: 11),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable Frosted Glass Container
  Widget _buildFrostedContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}


/// CustomPainter untuk segmen kurva temperatur per jam
class _HourlyCurveSegmentPainter extends CustomPainter {
  final double prevTemp;
  final double currTemp;
  final double nextTemp;

  _HourlyCurveSegmentPainter({
    required this.prevTemp,
    required this.currTemp,
    required this.nextTemp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const minRef = 20.0;
    const maxRef = 35.0;

    double getY(double t) {
      final normalized = ((t - minRef) / (maxRef - minRef)).clamp(0.0, 1.0);
      return size.height * 0.85 - (normalized * (size.height * 0.65));
    }

    final yPrev = getY(prevTemp);
    final yCurr = getY(currTemp);
    final yNext = getY(nextTemp);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, (yPrev + yCurr) / 2)
      ..quadraticBezierTo(size.width * 0.25, yCurr, size.width * 0.5, yCurr)
      ..quadraticBezierTo(size.width * 0.75, yCurr, size.width, (yCurr + yNext) / 2);

    canvas.drawPath(path, linePaint);

    final dotCenter = Offset(size.width * 0.5, yCurr);

    canvas.drawCircle(
      dotCenter,
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );

    canvas.drawCircle(
      dotCenter,
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _HourlyCurveSegmentPainter oldDelegate) {
    return oldDelegate.currTemp != currTemp;
  }
}

/// CustomPainter untuk busur siklus matahari (Sun Arc)
class _SunArcPainter extends CustomPainter {
  final double progress;

  _SunArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(8, 6, size.width - 16, (size.height - 6) * 2);
    canvas.drawArc(rect, math.pi, math.pi, false, arcPaint);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = Colors.white24
        ..strokeWidth = 1.0,
    );

    final angle = math.pi + (progress * math.pi);
    final radiusX = (size.width - 16) / 2;
    final radiusY = size.height - 6;
    final sunX = 8 + radiusX + (radiusX * math.cos(angle));
    final sunY = 6 + radiusY + (radiusY * math.sin(angle));

    final sunPos = Offset(sunX, sunY);

    canvas.drawCircle(
      sunPos,
      7.0,
      Paint()..color = const Color(0xFFFDE047).withValues(alpha: 0.35),
    );

    canvas.drawCircle(
      sunPos,
      3.5,
      Paint()..color = const Color(0xFFFEF08A),
    );
  }

  @override
  bool shouldRepaint(covariant _SunArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
