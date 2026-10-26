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
import '../../models/mountain.dart';
import '../../models/simaksi_permit.dart';
import '../../models/medical_profile.dart';
import '../../models/user_personal_data.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/weather_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/image_helper.dart';
import '../mountain/mountain_list_screen.dart';
import '../simaksi/simaksi_ticket_screen.dart';
import '../profile/profile_screen.dart';
import '../feedback/course_feedback_screen.dart';
import '../../widgets/ticket_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _DashboardPage(onTabChange: (index) => setState(() => _currentIndex = index)),
      const MountainListScreen(embedded: true),
      const SimaksiTicketScreen(embedded: true),
      const CourseFeedbackScreen(embedded: true),
      const ProfileScreen(embedded: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildAuraBottomBar(),
      floatingActionButton: _currentIndex == 0 ? const _AnimatedTbotBubble() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              icon: Icons.confirmation_num_outlined,
              activeIcon: Icons.confirmation_num_rounded,
              label: 'Simaksi',
            ),
            _buildNavItem(
              index: 3,
              icon: Icons.rate_review_outlined,
              activeIcon: Icons.rate_review_rounded,
              label: 'Saran',
            ),
            _buildNavItem(
              index: 4,
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profil',
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
    bool iconOnly = false,
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
            if (!iconOnly) ...[  
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
          ],
        ),
      ),
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
  final void Function(int)? onTabChange;
  const _DashboardPage({this.onTabChange});

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

  // Permits & Mountains future for pull-to-refresh
  late Future<List<SimaksiPermit>> _permitsFuture;
  late Future<List<Mountain>> _mountainsFuture;

  // Searchbar fungsional state
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Mountain> _allMountains = [];
  List<Mountain> _searchResults = [];
  bool _isSearching = false;

  // Smart Mountain Recommendation state
  List<SmartMountainRecommendation> _smartRecommendations = [];
  bool _isLoadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    _permitsFuture = _getRecentPermits();
    _mountainsFuture = _loadMountainsWithCache();
    _checkConnection();
    _fetchWeather();
    _loadSmartRecommendations();

    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });

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
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _connectivitySub?.cancel();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  Future<List<Mountain>> _loadMountainsWithCache() async {
    try {
      final list = await DatabaseService.instance.getAllMountains();
      if (mounted) {
        setState(() {
          _allMountains = list;
          if (_searchCtrl.text.trim().isNotEmpty) {
            _onSearchChanged(_searchCtrl.text);
          }
        });
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _isSearching = false;
        _searchResults.clear();
      } else {
        _isSearching = true;
        _searchResults = _allMountains.where((m) {
          final name = m.namaGunung.toLowerCase();
          final desc = (m.deskripsi ?? '').toLowerCase();
          final grade = m.tingkatBahaya.toLowerCase();
          final elev = '${m.elevasiMdpl}';
          return name.contains(q) || desc.contains(q) || grade.contains(q) || elev.contains(q);
        }).toList();
      }
    });
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

  /// Pull-to-refresh: Sinkron otomatis data, perbarui cuaca, status koneksi, tiket & gunung
  Future<void> _onRefresh() async {
    // 1. Eksekusi Sinkronisasi Data Otomatis
    final syncResult = await SyncService.instance.syncAll();

    // 2. Refresh Cuaca & Koneksi
    await Future.wait([
      _fetchWeather(),
      _checkConnection(),
    ]);

    // 3. Refresh Daftar Tiket, Gunung, & Rekomendasi TimurLang
    if (mounted) {
      setState(() {
        _permitsFuture = _getRecentPermits();
        _mountainsFuture = _loadMountainsWithCache();
      });
      _loadSmartRecommendations();

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
              // 1. Top Bar: Foto Profil + Halo Pendaki (Kiri Atas) & Status Sinyal Logo Saja (Kanan Atas)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Foto Profil Pengguna
                  GestureDetector(
                    onTap: () => widget.onTabChange?.call(4),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.textPrimary.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user?.fotoProfilUrl != null && user!.fotoProfilUrl!.isNotEmpty
                            ? Image(
                                image: ImageHelper.getImageProvider(user.fotoProfilUrl)!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppTheme.primarySubtle,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppTheme.primarySubtle,
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.primary,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nama & Ucapan Halo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${user?.namaLengkap ?? 'Pendaki'}!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppDateUtils.formatDateIndonesian(now),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Sinyal (Logo Saja)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isOnline ? AppTheme.primarySubtle : const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isOnline ? const Color(0xFFD4E0D2) : const Color(0xFFFCA5A5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isOnline ? AppTheme.primary : AppTheme.error).withValues(alpha: 0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        size: 18,
                        color: _isOnline ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Searchbar Cari Gunung (Fungsional, Realtime, & Interaktif)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _searchFocus.hasFocus ? AppTheme.primary : AppTheme.border,
                    width: _searchFocus.hasFocus ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.textPrimary.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    if (_searchResults.length == 1) {
                      _searchFocus.unfocus();
                      Navigator.pushNamed(
                        context,
                        AppRoutes.mountainDetail,
                        arguments: _searchResults.first,
                      );
                    } else if (_searchResults.isNotEmpty) {
                      _searchFocus.unfocus();
                      widget.onTabChange?.call(1);
                    }
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nama gunung, elevasi, atau lokasi...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  ),
                ),
              ),

              // Hasil Pencarian Realtime (Jika sedang mencari)
              if (_isSearching) ...[
                const SizedBox(height: 14),
                _buildSearchResultsSection(),
              ],
              const SizedBox(height: 22),

              // 3. Carousel Gunung-gunung (Gambar, CTA Mulai & Lihat Semua)
              _buildMountainCarousel(),
              const SizedBox(height: 22),

              // 4. Widget Cuaca di Dashboard (Bebas Overflow)
              _buildWeatherCardWidget(),
              const SizedBox(height: 22),

              // 5. Menu Utama (Sebaris 4 Saja)
              _buildCompactMenuSection(),
              const SizedBox(height: 24),

              // 5.5 Rekomendasi TimurLang Pendaki (AI Auto-sliding Carousel 3 Gunung)
              _buildSmartMountainRecommendationSection(),
              const SizedBox(height: 26),

              // 6. Section: Tiket Pembelian Terakhir (Preview 3 Terakhir + Lihat Semua)
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
                    onTap: () => widget.onTabChange?.call(2),
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

              // 7. Status Operasional Basecamp & Pengingat Perkiraan Matahari Tenggelam (Di Bawah Sendiri)
              _buildOperationalNoticeCard(isOperational, minutesToSunset),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Card Peringatan Jam Operasional Basecamp (Sunset / Night Alert)
  Widget _buildOperationalNoticeCard(bool isOperational, int minutesToSunset) {
    if (isOperational && minutesToSunset > 120) {
      return const SizedBox.shrink();
    }

    final isNight = !isOperational;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF1E293B) : const Color(0xFF291B10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNight ? const Color(0xFF334155) : const Color(0xFF78350F),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isNight ? Icons.nights_stay_rounded : Icons.wb_twilight_rounded,
                color: isNight ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isNight
                      ? 'Jam Operasional Basecamp Ditutup'
                      : 'Perkiraan Matahari Tenggelam (±$minutesToSunset Menit)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isNight
                ? 'Loket registrasi fisik ditutup (08:00 – 18:00 WIB). Layanan darurat SOS basecamp tetap siaga 24 jam.'
                : 'Batas operasional jalur pukul 18:00 WIB. Segera tiba di pos camp terdekat atau turun sebelum jalur gelap untuk keselamatan.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFFCBD5E1),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showNightSafetyModal(context, isNight),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lihat Panduan & SOP Keselamatan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isNight ? const Color(0xFF38BDF8) : const Color(0xFFFDE68A),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: isNight ? const Color(0xFF38BDF8) : const Color(0xFFFDE68A),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dialog Modal SOP Keselamatan Malam & Batas Operasional
  void _showNightSafetyModal(BuildContext context, bool isNight) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Standar Operasional Keselamatan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Kebijakan resmi pendakian & basecamp',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSopItem(
              icon: Icons.alarm_rounded,
              title: 'Jam Buka Pos Registrasi (08:00 – 18:00 WIB)',
              desc: 'Loket fisik ditutup tepat pukul 18:00 demi mencegah pendakian malam hari tanpa pemandu resmi.',
            ),
            const SizedBox(height: 12),
            _buildSopItem(
              icon: Icons.night_shelter_rounded,
              title: 'Pendaki yang Masih Berada di Jalur',
              desc: 'Wajib berhenti dan mendirikan tenda di Pos Camp resmi terdekat sebelum pukul 18:00 WIB.',
            ),
            const SizedBox(height: 12),
            _buildSopItem(
              icon: Icons.contact_phone_rounded,
              title: 'Bantuan Darurat & SAR (24 Jam)',
              desc: 'Jika membutuhkan bantuan medis atau evakuasi mendesak, aktifkan fitur SOS di aplikasi.',
            ),
            const SizedBox(height: 12),
            _buildSopItem(
              icon: Icons.smart_toy_rounded,
              title: 'Konsultasi 24 Jam dengan Tbot',
              desc: 'Tbot selalu aktif untuk menjawab rute, cuaca, tips survival, atau panduan pertolongan pertama (P3K).',
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Saya Mengerti',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSopItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Section Hasil Pencarian Interaktif di Dashboard
  Widget _buildSearchResultsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Pencarian
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Hasil Pencarian',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${_searchResults.length} Gunung',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jika Tidak Ada Hasil
          if (_searchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 44,
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Gunung "${_searchCtrl.text.trim()}" tidak ditemukan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coba kata kunci lain seperti "Prau", "Merbabu", atau "Lawu"',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Pencarian'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // List Gunung Hasil Pencarian
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
              separatorBuilder: (context, index) => const Divider(color: AppTheme.border, height: 16),
              itemBuilder: (context, index) {
                final mountain = _searchResults[index];
                final imageProvider = ImageHelper.getImageProvider(mountain.fotoUrl, mountain.namaGunung) ??
                    const AssetImage('assets/images/background_mount.png') as ImageProvider;
                final isClosed = mountain.statusJalur == 'Tutup';

                return InkWell(
                  onTap: () {
                    _searchFocus.unfocus();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.mountainDetail,
                      arguments: mountain,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Foto Gunung
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.primarySubtle,
                                child: const Icon(Icons.terrain_rounded, color: AppTheme.primary, size: 24),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Informasi Gunung
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mountain.namaGunung,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    '${mountain.elevasiMdpl} MDPL',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '•',
                                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      mountain.tingkatBahaya,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge & Arrow
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isClosed
                                    ? AppTheme.error.withValues(alpha: 0.12)
                                    : AppTheme.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                mountain.statusJalur,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isClosed ? AppTheme.error : AppTheme.success,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Tombol Lihat Semua di Tab Jelajah
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _searchFocus.unfocus();
                  widget.onTabChange?.call(1);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.primary, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Lihat Semua di Tab Gunung (${_searchResults.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// ── Carousel Gunung Horizontal dengan Gambar & CTA Mulai ──
  Widget _buildMountainCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Eksplorasi Gunung',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => widget.onTabChange?.call(1),
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
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: FutureBuilder<List<Mountain>>(
            future: _mountainsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }
              final mountains = snapshot.data ?? [];
              if (mountains.isEmpty) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Center(
                    child: Text(
                      'Belum ada data destinasi gunung',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: mountains.length,
                itemBuilder: (context, index) {
                  final mountain = mountains[index];
                  return _buildMountainCarouselCard(mountain);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Kartu Carousel Destinasi Gunung
  Widget _buildMountainCarouselCard(Mountain mountain) {
    final imageProvider = ImageHelper.getImageProvider(mountain.fotoUrl, mountain.namaGunung) ??
        const AssetImage('assets/images/background_mount.png') as ImageProvider;

    final isClosed = mountain.statusJalur == 'Tutup';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.mountainDetail, arguments: mountain),
      child: Container(
        width: 250,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textPrimary.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gambar Latar Gunung
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppTheme.primarySubtle,
                  child: const Center(
                    child: Icon(Icons.terrain_rounded, size: 48, color: AppTheme.primary),
                  ),
                ),
              ),

              // Gradient Scrim Gelap di Bawah
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),

              // Informasi Kartu
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Atas: Elevasi & Status Jalur
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Elevasi MDPL
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.terrain_rounded, size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '${mountain.elevasiMdpl} MDPL',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge Status Jalur
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isClosed
                                ? AppTheme.error.withValues(alpha: 0.9)
                                : AppTheme.success.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            mountain.statusJalur,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Nama Gunung
                    Text(
                      mountain.namaGunung,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Tingkat Bahaya & Tombol CTA Mulai
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            mountain.tingkatBahaya,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tombol CTA "Mulai"
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.mountainDetail,
                              arguments: mountain,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                              side: const BorderSide(color: Color(0xFF557A5E), width: 1),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Mulai',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ── Menu Utama Sebaris 4 Saja ──
  Widget _buildCompactMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Menu Utama',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompactMenuItem(
              label: 'Peta\nOffline',
              icon: Icons.map_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.map),
            ),
            _buildCompactMenuItem(
              label: 'Kompas',
              icon: Icons.explore_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.compass),
            ),
            _buildCompactMenuItem(
              label: 'SOS',
              icon: Icons.sos_rounded,
              onTap: () => Navigator.pushNamed(context, AppRoutes.fallDetection),
            ),
            _buildCompactMenuItem(
              label: 'Games',
              icon: Icons.sports_esports_outlined,
              onTap: () => Navigator.pushNamed(context, AppRoutes.mountainClimber),
            ),
          ],
        ),
      ],
    );
  }

  /// Item Menu Kompak Bulat/Kotak Halus
  Widget _buildCompactMenuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
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
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.2,
              ),
            ),
          ],
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
                          const SizedBox(width: 10),
                          _buildWeatherVisualIcon(_weatherData!.condition, _weatherData!.isStormWarning),
                          const Spacer(),
                          if (_weatherData!.isStormWarning)
                            Tooltip(
                              message: 'Peringatan Cuaca Ekstrem di Jalur',
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFFEE2E2),
                                  border: Border.all(
                                    color: AppTheme.error.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.error.withValues(alpha: 0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.warning_rounded,
                                    size: 19,
                                    color: AppTheme.error,
                                  ),
                                ),
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

                      // Metrics: Kelembaban + Kecepatan Angin (Bebas Overflow)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWeatherMetric(
                            Icons.water_drop_outlined,
                            'Lembab',
                            '${_weatherData!.humidity.toInt()}%',
                          ),
                          _buildWeatherMetric(
                            Icons.air_rounded,
                            'Angin',
                            '${_weatherData!.windSpeed.toStringAsFixed(1)} km/j',
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Detail',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
                            ],
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

  Widget _buildWeatherVisualIcon(String condition, bool isStorm) {
    IconData iconData = Icons.wb_sunny_rounded;
    Color iconColor = const Color(0xFFF59E0B);

    final lower = condition.toLowerCase();
    if (isStorm || lower.contains('badai') || lower.contains('petir')) {
      iconData = Icons.thunderstorm_rounded;
      iconColor = const Color(0xFF6366F1);
    } else if (lower.contains('hujan') || lower.contains('gerimis')) {
      iconData = Icons.water_drop_rounded;
      iconColor = const Color(0xFF38BDF8);
    } else if (lower.contains('awan') || lower.contains('mendung')) {
      iconData = Icons.cloud_rounded;
      iconColor = const Color(0xFF64748B);
    } else if (lower.contains('kabut')) {
      iconData = Icons.foggy;
      iconColor = const Color(0xFF94A3B8);
    }

    return Icon(iconData, size: 28, color: iconColor);
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
          onTap: () => _showTicketDetailModal(context, permit),
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
                          'Detail Tiket',
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

  /// Menampilkan detail tiket lengkap saat ditekan dari preview dashboard
  void _showTicketDetailModal(BuildContext context, SimaksiPermit permit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Detail Tiket Simaksi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TicketCard(permit: permit),
              ),
            ),
          ],
        ),
      ),
    );
  }

    Future<List<SimaksiPermit>> _getRecentPermits() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return [];
    return DatabaseService.instance.getPermitsByUser(user.id);
  }

  // ── Rekomendasi TimurLang PENDAKI (SMART MOUNTAIN RECOMMENDATIONS) ──

  Widget _buildSmartMountainRecommendationSection() {
    if (_isLoadingRecommendations) {
      return Container(
        height: 260,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_smartRecommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section Rekomendasi TimurLang
        Text(
          'Rekomendasi TimurLang',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // Carousel 3 Gunung yang bisa geser-geser sendiri
        _SmartRecommendationCarousel(
          recommendations: _smartRecommendations,
        ),
      ],
    );
  }

  Future<void> _loadSmartRecommendations() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingRecommendations = false);
      return;
    }

    try {
      final results = await Future.wait([
        DatabaseService.instance.getAllMountains(),
        DatabaseService.instance.getPermitsByUser(user.id),
        DatabaseService.instance.getPersonalData(user.id),
        DatabaseService.instance.getMedicalProfile(user.id),
      ]);

      final mountains = results[0] as List<Mountain>;
      final permits = results[1] as List<SimaksiPermit>;
      final personalData = results[2] as UserPersonalData?;
      final medicalProfile = results[3] as MedicalProfile?;

      if (mountains.isEmpty) {
        if (mounted) setState(() => _isLoadingRecommendations = false);
        return;
      }

      final recs = _generateSmartRecommendations(
        mountains: mountains,
        permits: permits,
        personalData: personalData,
        medicalProfile: medicalProfile,
        weather: _weatherData,
      );

      if (mounted) {
        setState(() {
          _smartRecommendations = recs;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      debugPrint('[SmartRecommendation] Error generating recommendations: $e');
      if (mounted) setState(() => _isLoadingRecommendations = false);
    }
  }

  List<SmartMountainRecommendation> _generateSmartRecommendations({
    required List<Mountain> mountains,
    required List<SimaksiPermit> permits,
    required UserPersonalData? personalData,
    required MedicalProfile? medicalProfile,
    required WeatherData? weather,
  }) {
    if (mountains.isEmpty) return [];

    // 1. Analisis Riwayat SIMAKSI
    final climbedNames = permits.map((p) => (p.namaGunung ?? p.gunungId).toLowerCase()).toSet();
    final int totalClimbs = permits.length;

    // 2. Analisis Data Rekam Medis
    final riwayatMedis = (medicalProfile?.riwayatPenyakit ?? '').toLowerCase();
    final bool hasSensitiveHealth = riwayatMedis.contains('asma') ||
        riwayatMedis.contains('paru') ||
        riwayatMedis.contains('sesak') ||
        riwayatMedis.contains('jantung') ||
        riwayatMedis.contains('hipertensi');

    // 3. Analisis Data Diri Lengkap
    final int userAge = personalData != null
        ? (DateTime.now().year - personalData.tanggalLahir.year)
        : 23;

    // 4. Analisis Cuaca Gunung
    final weatherCondition = weather?.condition ?? 'Cerah Berawan';
    final int temp = weather?.temperature.round() ?? 21;
    final bool isGoodWeather = weather == null ||
        (!weather.isStormWarning && !weather.condition.toLowerCase().contains('badai'));

    // 5. Penilaian Skor Kecocokan Personal
    final List<Map<String, dynamic>> scored = [];

    for (final m in mountains) {
      int score = 82;
      final bool isClimbed = climbedNames.contains(m.namaGunung.toLowerCase()) ||
          climbedNames.contains(m.id.toLowerCase());
      final bool isClosed = m.statusJalur == 'Tutup';

      if (isClosed) {
        score -= 25;
      }

      // Kriteria 1: Riwayat Simaksi
      String riwayatNote = '';
      if (totalClimbs == 0) {
        if (m.elevasiMdpl <= 2650) {
          score += 12;
          riwayatNote = 'Trek sangat ramah untuk pendakian perdana Anda';
        } else if (m.elevasiMdpl <= 3150) {
          score += 6;
          riwayatNote = 'Pilihan mantap untuk mencatat riwayat Simaksi pertama';
        } else {
          score -= 10;
          riwayatNote = 'Tantangan tinggi untuk pendaki baru';
        }
      } else if (totalClimbs <= 2) {
        if (m.elevasiMdpl >= 2500 && m.elevasiMdpl <= 3300) {
          score += 12;
          riwayatNote = isClimbed
              ? 'Jalur familiar berdasarkan riwayat Simaksi Anda'
              : 'Pilihan pas untuk naik level dari riwayat Simaksi Anda';
        } else {
          score += 6;
          riwayatNote = 'Alternatif segar dari riwayat pendakian Anda';
        }
      } else {
        if (m.elevasiMdpl >= 3000) {
          score += 15;
          riwayatNote = 'Sesuai jam terbang & riwayat $totalClimbs Simaksi Anda';
        } else {
          score += 8;
          riwayatNote = 'Cocok untuk tektok santai pendaki berpengalaman';
        }
      }

      // Kriteria 2: Rekam Medis
      String medisNote = '';
      if (hasSensitiveHealth) {
        if (m.elevasiMdpl <= 2600) {
          score += 14;
          medisNote = 'elevasi & oksigen aman untuk catatan pernapasan';
        } else {
          score -= 16;
          medisNote = 'perlu kehati-hatian ekstra terhadap catatan medis';
        }
      } else {
        score += 7;
        medisNote = 'data rekam medis prima mendukung durasi trek';
      }

      // Kriteria 3: Data Diri Lengkap
      String fisikNote = 'stamina usia $userAge thn';
      if (userAge >= 17 && userAge <= 40) {
        score += 4;
      }

      // Kriteria 4: Cuaca
      String cuacaNote = '$weatherCondition ($temp°C)';
      if (isGoodWeather) {
        score += 6;
      }

      score = score.clamp(74, 99);

      final String fullReason =
          '$riwayatNote, didukung $medisNote, $fisikNote, serta prakiraan cuaca $cuacaNote.';

      final List<String> tags = [
        cuacaNote,
        hasSensitiveHealth ? 'Ramah Pernapasan' : 'Rekam Medis Prima',
        totalClimbs == 0 ? 'Ramah Pemula' : 'Riwayat $totalClimbs Simaksi',
      ];

      scored.add({
        'mountain': m,
        'score': score,
        'reason': fullReason,
        'tags': tags,
      });
    }

    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    final topThree = scored.take(3).toList();
    final List<SmartMountainRecommendation> recs = [];

    const badges = [
      'Pilihan Terbaik #1',
      'Pilihan Ideal #2',
      'Alternatif Favorit #3',
    ];

    for (int i = 0; i < topThree.length; i++) {
      final item = topThree[i];
      recs.add(
        SmartMountainRecommendation(
          mountain: item['mountain'] as Mountain,
          matchScore: item['score'] as int,
          badgeText: i < badges.length ? badges[i] : 'Rekomendasi TimurLang',
          matchReason: item['reason'] as String,
          matchHighlights: List<String>.from(item['tags']),
        ),
      );
    }

    return recs;
  }
}

// ── MODEL DATA Rekomendasi TimurLang ──
class SmartMountainRecommendation {
  final Mountain mountain;
  final int matchScore;
  final String badgeText;
  final String matchReason;
  final List<String> matchHighlights;

  SmartMountainRecommendation({
    required this.mountain,
    required this.matchScore,
    required this.badgeText,
    required this.matchReason,
    required this.matchHighlights,
  });
}

// ── WIDGET CAROUSEL Rekomendasi TimurLang (GESER OTOMATIS) ──
class _SmartRecommendationCarousel extends StatefulWidget {
  final List<SmartMountainRecommendation> recommendations;
  const _SmartRecommendationCarousel({required this.recommendations});

  @override
  State<_SmartRecommendationCarousel> createState() => _SmartRecommendationCarouselState();
}

class _SmartRecommendationCarouselState extends State<_SmartRecommendationCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.recommendations.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
      if (!mounted || _isInteracting || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % widget.recommendations.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 270,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _isInteracting = true;
              } else if (notification is ScrollEndNotification) {
                _isInteracting = false;
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.recommendations.length,
              onPageChanged: (idx) {
                setState(() => _currentPage = idx);
              },
              itemBuilder: (context, index) {
                final rec = widget.recommendations[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildCard(rec),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Indikator Titik (Dot Indicator)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.recommendations.length, (i) {
            final active = i == _currentPage;
            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: active ? 22 : 6,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : AppTheme.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCard(SmartMountainRecommendation rec) {
    final imageProvider = ImageHelper.getImageProvider(rec.mountain.fotoUrl, rec.mountain.namaGunung) ??
        const AssetImage('assets/images/background_mount.png') as ImageProvider;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.mountainDetail, arguments: rec.mountain),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // 1. Foto Gunung
              Positioned.fill(
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF1B2E23),
                    child: const Center(
                      child: Icon(Icons.terrain_rounded, size: 48, color: Colors.white24),
                    ),
                  ),
                ),
              ),

              // 2. Gradient Overlay (Atas dan Bawah agar teks mudah terbaca)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.35, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 3. Konten Kartu
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Baris Atas: Badge Rekomendasi & Label MDPL di pojok kanan atas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.recommend_rounded, size: 14, color: Color(0xFF52B788)),
                              const SizedBox(width: 5),
                              Text(
                                'Rekomendasi Untukmu',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Label MDPL di pojok kanan atas (Tanpa icon dan tanpa outline, hijau solid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D6A4F),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            '${rec.mountain.elevasiMdpl} MDPL',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFE8F5E9),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Nama Gunung
                    Text(
                      rec.mountain.namaGunung,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Kotak Alasan Rekomendasi (Clean, human-curated style)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alasan Rekomendasi',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFA7C4B5),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            rec.matchReason,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tombol CTA (Tinggi 40, responsive, anti overflow i ->)
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.mountainDetail,
                          arguments: rec.mountain,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Jelajahi Jalur & Simaksi',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 15),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Balon Obrolan Tbot dengan Animasi Mengambang (Floating Bobbing & Breathing)
/// Memberi isyarat visual dinamis agar langsung menarik perhatian pengguna
class _AnimatedTbotBubble extends StatefulWidget {
  const _AnimatedTbotBubble();

  @override
  State<_AnimatedTbotBubble> createState() => _AnimatedTbotBubbleState();
}

class _AnimatedTbotBubbleState extends State<_AnimatedTbotBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _floatingAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatingAnim = Tween<double>(begin: 0.0, end: -7.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _rotateAnim = Tween<double>(begin: -0.018, end: 0.018).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double bubbleWidth = 130.0;
    const double bubbleHeight = 88.0;
    const double ovalHeight = 70.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnim.value),
          child: Transform.rotate(
            angle: _rotateAnim.value,
            alignment: const Alignment(0.6, 1.0),
            child: Transform.scale(
              scale: _scaleAnim.value,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, right: 6),
        child: Hero(
          tag: 'ai_survival_fab',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, AppRoutes.survivalAssistant),
              borderRadius: BorderRadius.circular(40),
              splashColor: Colors.white.withValues(alpha: 0.15),
              highlightColor: Colors.transparent,
              child: SizedBox(
                width: bubbleWidth,
                height: bubbleHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Gambar Balon Chat Komik (Oval + Kerucut Melengkung Terpadu)
                    CustomPaint(
                      size: const Size(bubbleWidth, bubbleHeight),
                      painter: _ComicSpeechBubblePainter(
                        color: AppTheme.primary,
                        borderColor: Colors.white.withValues(alpha: 0.25),
                        shadowColor: Colors.black.withValues(alpha: 0.28),
                      ),
                    ),
                    // Teks "Tanya Tbot" presisi di tengah-tengah badan oval
                    Positioned(
                      top: 0,
                      left: 0,
                      width: bubbleWidth,
                      height: ovalHeight,
                      child: Center(
                        child: Text(
                          'Tanya Tbot',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter untuk menggambar Balon Obrolan Komik (Oval + Kerucut Melengkung Menyatu)
class _ComicSpeechBubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color shadowColor;

  const _ComicSpeechBubblePainter({
    required this.color,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ovalH = h - 16.0; // Tinggi badan oval

    // 1. Badan Oval Sempurna
    final ovalPath = Path()..addOval(Rect.fromLTWH(0, 0, w, ovalH));

    // 2. Ekor Kerucut Melengkung Khas Komik (persis gambar referensi)
    final tailPath = Path()
      ..moveTo(w * 0.58, ovalH * 0.95)
      ..quadraticBezierTo(w * 0.69, h * 0.92, w * 0.80, h)
      ..quadraticBezierTo(w * 0.77, h * 0.81, w * 0.83, ovalH * 0.73)
      ..close();

    // 3. Satukan menjadi satu siluet tanpa garis sambungan
    final bubblePath = Path.combine(PathOperation.union, ovalPath, tailPath);

    // Gambar bayangan halus
    canvas.drawShadow(bubblePath, shadowColor, 8, true);

    // Isi warna gelembung
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(bubblePath, fillPaint);

    // Garis tepi halus
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(bubblePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}




