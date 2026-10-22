// ============================================
// TimurLang - Weather Screen (OpenWeatherMap)
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  WeatherData? _currentWeather;
  List<WeatherForecast> _forecast = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCity;
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _loadWeather();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather({String? cityName}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (cityName != null) {
        _selectedCity = cityName;
        _searchCtrl.text = cityName;
      }
    });

    try {
      WeatherData current;
      List<WeatherForecast> forecast;

      if (_selectedCity != null) {
        current = await WeatherService.instance.getWeatherByCity(_selectedCity!);
        forecast = await WeatherService.instance.getForecastByCity(_selectedCity!);
      } else {
        // Use null to trigger GPS-based location detection
        current = await WeatherService.instance.getCurrentWeather(null, null);
        forecast = await WeatherService.instance.getForecast(null, null);
      }

      if (mounted) {
        setState(() {
          _currentWeather = current;
          _forecast = forecast;
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi Cuaca'),
        actions: [
          if (_selectedCity != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: 'Gunakan GPS saya',
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _selectedCity = null);
                _loadWeather();
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui cuaca',
            onPressed: _isLoading ? null : () => _loadWeather(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Mengambil data cuaca...',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mendeteksi lokasi satelit Anda...',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadWeather,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentWeather == null) {
      return Center(
        child: Text(
          'Gagal memuat data cuaca.',
          style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
        onRefresh: _loadWeather,
        color: AppTheme.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Storm Warning Banner
              if (_currentWeather!.isStormWarning)
                _buildStormWarning(),

              // Search Bar Diatas Card Lokasi
              _buildSearchBar(),

              // Location Header
              _buildLocationHeader(),
              const SizedBox(height: 16),

              // Current Weather Card
              _buildCurrentWeatherCard(),
              const SizedBox(height: 20),

              // Weather Details Grid
              _buildWeatherDetailsGrid(),
              const SizedBox(height: 28),

              // Hiking Safety Indicator
              _buildHikingSafetyCard(),
              const SizedBox(height: 28),

              // Forecast Header
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Prakiraan Cuaca',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_forecast.length} hari',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Forecast List
              ..._forecast.asMap().entries.map((entry) => _buildForecastItem(entry.value, entry.key)),

              const SizedBox(height: 16),

              // Data source footer
              Center(
                child: Text(
                  'Stasiun OpenWeatherMap (${DateFormat('HH:mm').format(_currentWeather!.stationTime)} WIB) • Sync: ${DateFormat('HH:mm').format(_currentWeather!.lastUpdated)} WIB',
                  style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStormWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: AppTheme.dangerGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dangerRed.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERINGATAN CUACA BURUK',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentWeather!.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatLocationTitle(WeatherData weather) {
    if (_selectedCity != null) return _selectedCity!;
    if (weather.locationName == 'Depok' && weather.latitude < -7.5) {
      return 'Depok, Sleman (DIY)';
    }
    return weather.locationName;
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13.5,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Cari wilayah/kabupaten (mis. Sleman, Malang)...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppTheme.textSecondary.withValues(alpha: 0.8),
          ),
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 21),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchCtrl.text.isNotEmpty || _selectedCity != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                  tooltip: 'Kembali ke GPS Live',
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _selectedCity = null);
                    _loadWeather();
                  },
                ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.primary),
                tooltip: 'Cari Wilayah',
                onPressed: () {
                  final val = _searchCtrl.text.trim();
                  if (val.isNotEmpty) {
                    _loadWeather(cityName: val);
                  }
                },
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onSubmitted: (val) {
          if (val.trim().isNotEmpty) {
            _loadWeather(cityName: val.trim());
          }
        },
      ),
    );
  }

  Widget _buildLocationHeader() {
    final weather = _currentWeather!;
    final locationTitle = _formatLocationTitle(weather);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.redAccent, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationTitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedCity != null
                      ? 'Pencarian manual • Tap icon GPS di atas untuk kembali'
                      : 'GPS: ${weather.latitude.toStringAsFixed(4)}°, ${weather.longitude.toStringAsFixed(4)}°',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedCity != null
                  ? Colors.blueGrey.withValues(alpha: 0.15)
                  : AppTheme.primarySubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _selectedCity != null
                    ? Colors.blueGrey.withValues(alpha: 0.4)
                    : AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _selectedCity != null ? Colors.cyanAccent : AppTheme.safeGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _selectedCity != null ? 'MANUAL' : 'GPS LIVE',
                  style: TextStyle(
                    color: _selectedCity != null ? Colors.cyanAccent : AppTheme.safeGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCard() {
    final weather = _currentWeather!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: _getWeatherGradient(weather.condition),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            weather.icon,
            style: const TextStyle(fontSize: 68),
          ),
          const SizedBox(height: 4),
          Text(
            '${weather.temperature.toStringAsFixed(1)}°C',
            style: const TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Terasa seperti ${weather.feelsLike.toStringAsFixed(1)}°C',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              const Text('•', style: TextStyle(color: Colors.white38)),
              const SizedBox(width: 8),
              Text(
                'Min ${weather.tempMin.toStringAsFixed(0)}° / Max ${weather.tempMax.toStringAsFixed(0)}°',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            weather.condition,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              weather.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetailsGrid() {
    final weather = _currentWeather!;
    final sunriseTime = DateTime.fromMillisecondsSinceEpoch(weather.sunrise * 1000);
    final sunsetTime = DateTime.fromMillisecondsSinceEpoch(weather.sunset * 1000);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildDetailTile(
          Icons.water_drop_outlined,
          '${weather.humidity.toStringAsFixed(0)}%',
          'Kelembapan',
          Colors.lightBlueAccent,
        ),
        _buildDetailTile(
          Icons.air,
          '${weather.windSpeed.toStringAsFixed(1)} km/h',
          'Kec. Angin',
          Colors.cyanAccent,
        ),
        _buildDetailTile(
          Icons.compress,
          '${weather.pressure.toStringAsFixed(0)} hPa',
          'Tekanan Udara',
          Colors.orangeAccent,
        ),
        _buildDetailTile(
          Icons.visibility_outlined,
          '${(weather.visibility / 1000).toStringAsFixed(1)} km',
          'Jarak Pandang',
          Colors.amberAccent,
        ),
        _buildDetailTile(
          Icons.cloud_outlined,
          '${weather.clouds}%',
          'Tutupan Awan',
          Colors.blueGrey,
        ),
        if (weather.rain1h != null)
          _buildDetailTile(
            Icons.umbrella,
            '${weather.rain1h!.toStringAsFixed(1)} mm',
            'Curah Hujan/Jam',
            Colors.indigoAccent,
          )
        else
          _buildDetailTile(
            Icons.wb_sunny_outlined,
            '${DateFormat('HH:mm').format(sunriseTime)} / ${DateFormat('HH:mm').format(sunsetTime)}',
            'Terbit / Terbenam',
            Colors.amber,
          ),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String value, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHikingSafetyCard() {
    final weather = _currentWeather!;
    final safety = _getHikingSafety(weather);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: safety.color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hiking, color: safety.color, size: 22),
              const SizedBox(width: 10),
              Text(
                'Status Keamanan Pendakian',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: safety.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: safety.color.withValues(alpha: 0.5)),
                ),
                child: Text(
                  safety.label,
                  style: GoogleFonts.plusJakartaSans(
                    color: safety.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              ...List.generate(5, (i) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(
                  Icons.circle,
                  size: 10,
                  color: i < safety.level ? safety.color : AppTheme.border,
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            safety.advice,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastItem(WeatherForecast forecast, int index) {
    const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    // Menggunakan index weekday (1 = Senin .. 7 = Minggu)
    final dayName = dayNames[(forecast.date.weekday - 1) % 7];
    final dateStr = '${forecast.date.day} ${monthNames[(forecast.date.month - 1) % 12]}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Day & Date
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  dateStr,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Weather icon & condition
          Expanded(
            child: Row(
              children: [
                Text(forecast.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forecast.condition,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (forecast.pop > 0)
                        Text(
                          'Hujan ${(forecast.pop * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF0284C7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Temperature range
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${forecast.tempMax.toStringAsFixed(0)}°',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '${forecast.tempMin.toStringAsFixed(0)}°',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LinearGradient _getWeatherGradient(String condition) {
    switch (condition) {
      case 'Cerah':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
        );
      case 'Berawan':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF546E7A), Color(0xFF78909C)],
        );
      case 'Hujan':
      case 'Gerimis':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF37474F), Color(0xFF455A64)],
        );
      case 'Badai Petir':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        );
      case 'Kabut Tebal':
      case 'Kabut Tipis':
      case 'Kabut Asap':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF616161), Color(0xFF9E9E9E)],
        );
      default:
        return AppTheme.skyGradient;
    }
  }

  _HikingSafety _getHikingSafety(WeatherData weather) {
    // Storm or thunderstorm
    if (weather.isStormWarning) {
      return _HikingSafety(
        label: 'BERBAHAYA',
        level: 1,
        color: AppTheme.dangerRed,
        advice: 'Cuaca sangat berbahaya untuk pendakian. Tunda perjalanan dan cari perlindungan segera.',
      );
    }

    // Heavy rain
    if (weather.condition == 'Hujan' && weather.windSpeed > 30) {
      return _HikingSafety(
        label: 'BERISIKO TINGGI',
        level: 2,
        color: Colors.orangeAccent,
        advice: 'Hujan disertai angin kencang. Jalur kemungkinan licin dan berbahaya. Pertimbangkan ulang pendakian.',
      );
    }

    // Low visibility
    if (weather.visibility < 1000) {
      return _HikingSafety(
        label: 'WASPADA',
        level: 2,
        color: Colors.orangeAccent,
        advice: 'Jarak pandang sangat rendah (< 1 km). Navigasi sulit, gunakan GPS dan tetap di jalur yang ditandai.',
      );
    }

    // Moderate conditions
    if (weather.condition == 'Hujan' ||
        weather.condition == 'Gerimis' ||
        weather.windSpeed > 20 ||
        weather.humidity > 90) {
      return _HikingSafety(
        label: 'HATI-HATI',
        level: 3,
        color: AppTheme.warningYellow,
        advice: 'Cuaca kurang ideal. Siapkan jas hujan, perlengkapan tahan air, dan berhati-hati di jalur licin.',
      );
    }

    // Cloudy but OK
    if (weather.condition == 'Mendung' || weather.clouds > 80) {
      return _HikingSafety(
        label: 'CUKUP AMAN',
        level: 4,
        color: Colors.lightGreenAccent,
        advice: 'Mendung tapi aman untuk pendakian. Siapkan jas hujan untuk berjaga-jaga.',
      );
    }

    // Clear / Good weather
    return _HikingSafety(
      label: 'AMAN',
      level: 5,
      color: AppTheme.safeGreen,
      advice: 'Cuaca ideal untuk pendakian! Tetap bawa perlengkapan standar dan cukup air minum.',
    );
  }
}

class _HikingSafety {
  final String label;
  final int level;
  final Color color;
  final String advice;

  _HikingSafety({
    required this.label,
    required this.level,
    required this.color,
    required this.advice,
  });
}
