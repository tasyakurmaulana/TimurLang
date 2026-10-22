// ============================================
// TimurLang - Home Screen (Pendaki Dashboard)
// Adapted with Aura Travel Design System
// (Serene organic aesthetic, Playfair Display + Plus Jakarta Sans)
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../models/simaksi_permit.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/weather_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/image_helper.dart';
import '../mountain/mountain_list_screen.dart';
import '../profile/profile_screen.dart';
import '../feedback/course_feedback_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _DashboardPage(),
    const MountainListScreen(embedded: true),
    const ProfileScreen(embedded: true),
    const CourseFeedbackScreen(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildAuraBottomBar(),
      floatingActionButton: _currentIndex == 0 ? _buildAiFloatingButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// AI Survival Assistant Floating Action Button (Melayang di kanan bawah)
  Widget _buildAiFloatingButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8, right: 4),
      child: FloatingActionButton.extended(
        heroTag: 'ai_survival_fab',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.survivalAssistant),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: const BorderSide(color: Color(0xFF557A5E), width: 1.2),
        ),
        icon: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
        ),
        label: Text(
          'Tanya AI',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAuraBottomBar() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: AppTheme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              index: 0,
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Beranda',
            ),
            _buildNavItem(
              index: 1,
              icon: Icons.terrain_outlined,
              activeIcon: Icons.terrain_rounded,
              label: 'Gunung',
            ),
            _buildNavItem(
              index: 2,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profil',
              customIcon: _buildProfileIcon(_currentIndex == 2),
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.rate_review_outlined,
              activeIcon: Icons.rate_review_rounded,
              label: 'Saran',
            ),
            _buildNavItem(
              index: 4,
              icon: Icons.logout_rounded,
              activeIcon: Icons.logout_rounded,
              label: 'Keluar',
              isLogout: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    Widget? customIcon,
    bool isLogout = false,
  }) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (isLogout) {
          _showLogoutDialog();
        } else {
          setState(() => _currentIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon ??
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isLogout
                      ? AppTheme.error
                      : (isSelected ? AppTheme.primary : AppTheme.textSecondary),
                  size: 22,
                ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isLogout
                    ? AppTheme.error
                    : (isSelected ? AppTheme.primary : AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIcon(bool isSelected) {
    final user = AuthService.instance.currentUser;
    final provider = ImageHelper.getImageProvider(user?.fotoProfilUrl);
    if (provider != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 10,
          backgroundImage: provider,
        ),
      );
    }
    return Icon(
      isSelected ? Icons.person_rounded : Icons.person_outline_rounded,
      color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
      size: 22,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppTheme.border, width: 1),
        ),
        title: Text(
          'Keluar dari Akun',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari aplikasi TimurLang?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.border, width: 1),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dashboard Page ──
class _DashboardPage extends StatefulWidget {
  const _DashboardPage();

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _connectivityTimer;

  // Weather state for dedicated dashboard widget
  WeatherData? _weatherData;
  bool _isLoadingWeather = true;

  // Permits future for pull-to-refresh
  late Future<List<SimaksiPermit>> _permitsFuture;

  @override
  void initState() {
    super.initState();
    _permitsFuture = _getRecentPermits();
    _checkConnection();
    _fetchWeather();

    // Dengarkan perubahan koneksi secara real-time
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final online = !result.contains(ConnectivityResult.none);
      if (mounted && _isOnline != online) {
        setState(() => _isOnline = online);
      }
    });
    // Timer cadangan: periksa ulang setiap 10 detik
    _connectivityTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) => _checkConnection());
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final online = await SyncService.instance.hasConnection();
    if (mounted && _isOnline != online) setState(() => _isOnline = online);
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;
    setState(() => _isLoadingWeather = true);
    try {
      final data = await WeatherService.instance.getCurrentWeather(null, null);
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoadingWeather = false;
        });
      }
    } catch (_) {
      try {
        final fallback = await WeatherService.instance.getWeatherByCity('Magelang,ID');
        if (mounted) {
          setState(() {
            _weatherData = fallback;
            _isLoadingWeather = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingWeather = false);
        }
      }
    }
  }

  /// Pull-to-refresh: Sinkron otomatis data, perbarui cuaca, status koneksi & tiket
  Future<void> _onRefresh() async {
    // 1. Eksekusi Sinkronisasi Data Otomatis
    final syncResult = await SyncService.instance.syncAll();

    // 2. Refresh Cuaca & Koneksi
    await Future.wait([
      _fetchWeather(),
      _checkConnection(),
    ]);

    // 3. Refresh Daftar Tiket
    if (mounted) {
      setState(() {
        _permitsFuture = _getRecentPermits();
      });

      final isSuccess = syncResult.failed == 0;
      // Tampilkan feedback notifikasi sinkronisasi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSuccess ? Icons.cloud_done_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  syncResult.message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isSuccess ? AppTheme.primary : AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final now = DateTime.now();
    final isOperational = AppDateUtils.isWithinOperationalHours(now);
    final minutesToSunset = AppDateUtils.minutesUntilOperationalEnd(now);

    return SafeArea(
      child: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Halo Pendaki + Status Daring/Luring Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user?.namaLengkap ?? 'Pendaki'}! 👋',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppDateUtils.formatDateIndonesian(now),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Aura Daring/Luring Pill Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnline ? AppTheme.primarySubtle : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: _isOnline ? const Color(0xFFD4E0D2) : const Color(0xFFFCA5A5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          size: 14,
                          color: _isOnline ? AppTheme.success : AppTheme.error,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isOnline ? 'Daring' : 'Luring',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _isOnline ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Operational Hours Alert (Aura Tonal Card)
              if (!isOperational || minutesToSunset <= 120)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isOperational ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOperational ? const Color(0xFFFDE68A) : const Color(0xFFFCA5A5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOperational ? Icons.wb_twilight_rounded : Icons.nightlight_round,
                        color: isOperational ? AppTheme.warning : AppTheme.error,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isOperational
                              ? 'Matahari terbenam dalam $minutesToSunset menit (Batas operasional 18:00)'
                              : 'Di luar jam operasional pendakian resmi (08:00 - 18:00)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isOperational ? const Color(0xFF92400E) : AppTheme.error,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Dedicated Weather Widget di Dashboard ──
              _buildWeatherCardWidget(),
              const SizedBox(height: 22),

              // Section: Menu Utama (6 Fitur Inti yang Rapi)
              Text(
                'Menu Utama',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  _buildAuraMenuCard(
                    'Peta\nOffline',
                    Icons.map_outlined,
                    AppTheme.primary,
                    () => Navigator.pushNamed(context, AppRoutes.map),
                  ),
                  _buildAuraMenuCard(
                    'Kompas\n3D',
                    Icons.explore_outlined,
                    AppTheme.secondary,
                    () => Navigator.pushNamed(context, AppRoutes.compass),
                  ),
                  _buildAuraMenuCard(
                    'Tiket\nSimaksi',
                    Icons.confirmation_num_outlined,
                    AppTheme.secondary,
                    () => Navigator.pushNamed(context, AppRoutes.simaksiTicket),
                  ),
                  _buildAuraMenuCard(
                    'Pendaki\nGunung',
                    Icons.sports_esports_outlined,
                    AppTheme.primary,
                    () => Navigator.pushNamed(context, AppRoutes.mountainClimber),
                  ),
                  _buildAuraMenuCard(
                    'Rekam\nMedis',
                    Icons.medical_information_outlined,
                    const Color(0xFF0284C7),
                    () => Navigator.pushNamed(context, AppRoutes.medicalProfile),
                  ),
                  _buildAuraMenuCard(
                    'Saran &\nEvaluasi',
                    Icons.rate_review_outlined,
                    AppTheme.warning,
                    () => Navigator.pushNamed(context, AppRoutes.courseFeedback),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section: Tiket Terbaru (3 Terakhir + Lihat Semua)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiket Terbaru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.simaksiTicket),
                    child: Row(
                      children: [
                        Text(
                          'Lihat Semua',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Recent Permits List (Tampilan Preview Ramping 3 Tiket Terakhir)
              FutureBuilder<List<SimaksiPermit>>(
                future: _permitsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppTheme.primarySubtle,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFD4E0D2), width: 1),
                            ),
                            child: const Icon(
                              Icons.confirmation_num_outlined,
                              size: 26,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum Ada Tiket Simaksi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Daftarkan izin pendakian Anda untuk memulai petualangan.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final permits = snapshot.data!;
                  // Tampilkan maksimal 3 tiket terakhir dalam bentuk preview
                  final displayCount = permits.length > 3 ? 3 : permits.length;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayCount,
                    itemBuilder: (context, index) {
                      return _buildTicketPreviewCard(permits[index]);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Dedicated Aura Weather Card Widget
  Widget _buildWeatherCardWidget() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.weather),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isLoadingWeather
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Memuat prakiraan cuaca jalur...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : _weatherData != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Lokasi & Status Pill
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primarySubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _weatherData!.locationName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _weatherData!.isStormWarning
                                  ? const Color(0xFFFEE2E2)
                                  : AppTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(
                                color: _weatherData!.isStormWarning
                                    ? const Color(0xFFFCA5A5)
                                    : const Color(0xFFD4E0D2),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _weatherData!.condition,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _weatherData!.isStormWarning
                                        ? AppTheme.error
                                        : AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: _weatherData!.isStormWarning
                                      ? AppTheme.error
                                      : AppTheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Main Weather Row: Suhu + Emoji + Jalur Status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${_weatherData!.temperature.round()}°C',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _weatherData!.icon,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const Spacer(),
                          // Badge Jalur Aman / Waspada
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _weatherData!.isStormWarning
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _weatherData!.isStormWarning
                                      ? Icons.warning_amber_rounded
                                      : Icons.verified_rounded,
                                  size: 14,
                                  color: _weatherData!.isStormWarning
                                      ? AppTheme.error
                                      : AppTheme.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _weatherData!.isStormWarning ? 'Waspada' : 'Jalur Aman',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _weatherData!.isStormWarning
                                        ? AppTheme.error
                                        : AppTheme.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Ringkasan Kondisi
                      Text(
                        _weatherData!.description,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppTheme.border),
                      const SizedBox(height: 10),

                      // Metrics: Kelembaban + Kecepatan Angin
                      Row(
                        children: [
                          _buildWeatherMetric(
                            Icons.water_drop_outlined,
                            'Kelembaban',
                            '${_weatherData!.humidity.toInt()}%',
                          ),
                          const SizedBox(width: 18),
                          _buildWeatherMetric(
                            Icons.air_rounded,
                            'Angin',
                            '${_weatherData!.windSpeed.toStringAsFixed(1)} km/j',
                          ),
                          const Spacer(),
                          Text(
                            'Detail cuaca →',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: AppTheme.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data cuaca belum tersedia (Tarik untuk sinkron)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchWeather,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWeatherMetric(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.secondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Tampilan Preview Ramping untuk Tiket di Home Dashboard
  Widget _buildTicketPreviewCard(SimaksiPermit permit) {
    Color statusColor;
    switch (permit.statusIzin) {
      case 'Terdaftar':
        statusColor = AppTheme.secondary;
        break;
      case 'Tervalidasi':
        statusColor = AppTheme.success;
        break;
      case 'Di Jalur':
        statusColor = AppTheme.warning;
        break;
      case 'Selesai':
        statusColor = AppTheme.textSecondary;
        break;
      case 'Ditolak':
        statusColor = AppTheme.error;
        break;
      default:
        statusColor = AppTheme.warning;
    }

    final bookingCode = permit.id.length >= 8
        ? permit.id.substring(0, 8).toUpperCase()
        : permit.id.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pushNamed(context, AppRoutes.simaksiTicket),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris Atas: Ikon + Nama Gunung & Kode Booking + Status Pill
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD4E0D2), width: 1),
                      ),
                      child: const Icon(
                        Icons.confirmation_num_outlined,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            permit.namaGunung ?? 'Izin Pendakian',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kode: #$bookingCode',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        permit.statusIzin,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 10),
                // Baris Bawah: Jadwal Tanggal + Rombongan + Detail Action
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      AppDateUtils.formatDateIndonesian(permit.tanggalNaik),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    const Icon(Icons.group_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${permit.jumlahAnggota} Pendaki',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'Lihat Tiket',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: AppTheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<SimaksiPermit>> _getRecentPermits() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return [];
    return DatabaseService.instance.getPermitsByUser(user.id);
  }

  Widget _buildAuraMenuCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

