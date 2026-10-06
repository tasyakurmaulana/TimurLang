// ============================================
// TimurLang - Home Screen (Pendaki Dashboard)
// With Bottom Navigation Bar
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../utils/date_utils.dart';
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
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            if (i == 4) {
              // Logout
              _showLogoutDialog();
            } else {
              setState(() => _currentIndex = i);
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Beranda',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.terrain),
              label: 'Gunung',
            ),
            BottomNavigationBarItem(
              icon: _buildProfileIcon(),
              label: 'Profil',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.rate_review_rounded),
              label: 'Saran',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.logout_rounded),
              label: 'Keluar',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIcon() {
    final user = AuthService.instance.currentUser;
    if (user?.fotoProfilUrl != null) {
      return CircleAvatar(
        radius: 12,
        backgroundImage: NetworkImage(user!.fotoProfilUrl!),
      );
    }
    return const Icon(Icons.person_rounded);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            child: const Text('Keluar'),
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

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    final online = await SyncService.instance.hasConnection();
    if (mounted) setState(() => _isOnline = online);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final now = DateTime.now();
    final isOperational = AppDateUtils.isWithinOperationalHours(now);
    final minutesToSunset = AppDateUtils.minutesUntilOperationalEnd(now);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${user?.namaLengkap ?? 'Pendaki'}! 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppDateUtils.formatDateIndonesian(now),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? AppTheme.safeGreen.withValues(alpha: 0.15)
                        : AppTheme.dangerRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 14,
                        color: _isOnline ? AppTheme.safeGreen : AppTheme.dangerRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? 'Daring' : 'Luring',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isOnline ? AppTheme.safeGreen : AppTheme.dangerRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Operational hours warning
            if (!isOperational || minutesToSunset <= 120)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: isOperational ? null : AppTheme.dangerGradient,
                  color: isOperational ? AppTheme.warningYellow.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOperational ? Icons.wb_twilight : Icons.nightlight,
                      color: isOperational ? AppTheme.warningYellow : Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOperational
                            ? '⚠️ Matahari terbenam dalam $minutesToSunset menit'
                            : '🌙 Di luar jam operasional pendakian (08:00-18:00)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isOperational ? AppTheme.warningYellow : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Quick Actions Grid
            const Text(
              'Menu Utama',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1,
              children: [
                _menuCard('Peta\nOffline', Icons.map_rounded, AppTheme.skyBlue, () {
                  Navigator.pushNamed(context, AppRoutes.map);
                }),
                _menuCard('Cuaca', Icons.cloud_rounded, AppTheme.accentAmber, () {
                  Navigator.pushNamed(context, AppRoutes.weather);
                }),
                _menuCard('Kompas\n3D', Icons.explore_rounded, AppTheme.primaryGreen, () {
                  Navigator.pushNamed(context, AppRoutes.compass);
                }),
                _menuCard('SOS\nDarurat', Icons.sos_rounded, AppTheme.dangerRed, () {
                  Navigator.pushNamed(context, AppRoutes.fallDetection);
                }),
                _menuCard('Survival\nAssistant', Icons.smart_toy_rounded, Color(0xFF7B1FA2), () {
                  Navigator.pushNamed(context, AppRoutes.survivalAssistant);
                }),
                _menuCard('Tiket\nSimaksi', Icons.confirmation_num_rounded, AppTheme.accentOrange, () {
                  Navigator.pushNamed(context, AppRoutes.simaksiTicket);
                }),
                _menuCard('Pack\nCarrier', Icons.backpack_rounded, Color(0xFF00695C), () {
                  Navigator.pushNamed(context, AppRoutes.packCarrier);
                }),
                _menuCard('Rekam\nMedis', Icons.medical_information_rounded, Color(0xFF1565C0), () {
                  Navigator.pushNamed(context, AppRoutes.medicalProfile);
                }),
                _menuCard('Sinkron\nData', Icons.sync_rounded, AppTheme.mistGrey, () async {
                  final result = await SyncService.instance.syncAll();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result.message)),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            // Recent permits
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tiket Terbaru',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.simaksiTicket),
                  child: Text(
                    'Lihat Semua →',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder(
              future: _getRecentPermits(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.confirmation_num_outlined, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada tiket Simaksi',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List> _getRecentPermits() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return [];
    return DatabaseService.instance.getPermitsByUser(user.id);
  }

  Widget _menuCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
