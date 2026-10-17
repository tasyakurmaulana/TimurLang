// ============================================
// TimurLang - Basecamp Dashboard Screen
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../models/basecamp_post.dart';
import '../../models/mountain.dart';
import '../../models/sos_incident.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';

class BasecampDashboardScreen extends StatefulWidget {
  const BasecampDashboardScreen({super.key});

  @override
  State<BasecampDashboardScreen> createState() => _BasecampDashboardScreenState();
}

class _BasecampDashboardScreenState extends State<BasecampDashboardScreen> {
  int _activeSOS = 0;
  int _activeHikers = 0;
  List<SosIncident> _activeSosList = [];
  BasecampPost? _basecampPost;
  Mountain? _mountain;
  Timer? _pollingTimer;
  final Set<String> _knownSosIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    // Polling setiap 5 detik untuk memeriksa sinyal SOS darurat khusus basecamp ini
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    BasecampPost? post = _basecampPost;
    post ??= await DatabaseService.instance.getBasecampByUserId(user.id);
    
    final gunungId = user.gunungId ?? post?.gunungId ?? 'mtn-001';
    Mountain? mtn = _mountain;
    mtn ??= await DatabaseService.instance.getMountainById(gunungId);

    // Ambil SOS hanya untuk gunung & basecamp ini
    final sosList = await DatabaseService.instance.getActiveSOSIncidentsForBasecamp(
      gunungId: gunungId,
      basecampId: post?.id,
    );

    // Ambil izin pendaki di jalur khusus gunung & basecamp ini
    final permits = await DatabaseService.instance.getActivePermitsForBasecamp(
      gunungId: gunungId,
      basecampId: post?.id,
    );

    // Deteksi SOS baru untuk memicu alarm / notifikasi lokal di perangkat petugas
    for (final inc in sosList) {
      if (!_knownSosIds.contains(inc.id)) {
        _knownSosIds.add(inc.id);
        if (silent) {
          await NotificationService.instance.showSOSNotification(
            title: '🚨 DARURAT PENDAKI DI ${mtn?.namaGunung.toUpperCase() ?? 'JALUR'}!',
            body: 'Pendaki ${inc.namaPendaki ?? 'Anonim'} mengirim sinyal SOS di koordinat (${inc.koordinatLat.toStringAsFixed(4)}, ${inc.koordinatLong.toStringAsFixed(4)})!',
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _basecampPost = post;
        _mountain = mtn;
        _activeSosList = sosList;
        _activeSOS = sosList.length;
        _activeHikers = permits.length;
      });
    }
  }

  Future<void> _resolveSOS(String sosId) async {
    await DatabaseService.instance.updateSOSStatus(sosId, AppConstants.sosHandled);
    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.updateSosStatus(sosId, AppConstants.sosHandled);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Status darurat ditandai: DITANGANI'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );
    _loadData();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Basecamp?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
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

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final displayBasecampName = user?.namaBasecamp ?? _basecampPost?.namaPos ?? 'Pos Basecamp';
    final displayMountainName = _mountain?.namaGunung ?? 'Gunung Wilayah';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Basecamp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final res = await SyncService.instance.syncAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Petugas & Basecamp Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.darkCardGradient,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.home_work, color: AppTheme.primaryGreen, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayBasecampName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayMountainName,
                                style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.white12),
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          'Petugas: ${user?.namaLengkap ?? 'Pengelola'}',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Resmi Terverifikasi',
                            style: TextStyle(fontSize: 10, color: AppTheme.safeGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SOS Alert Banner & Items (HANYA MUNCUL JIKA ADA SOS DARI PENDAKI DI GUNUNG/BASECAMP INI)
              if (_activeSOS > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.dangerGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.dangerRed.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PERINGATAN DARURAT AKTIF!',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                ),
                                Text(
                                  '$_activeSOS pendaki di jalur Anda membunyikan sinyal darurat!',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // List of SOS Incidents
                      ..._activeSosList.map((sos) {
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_pin_circle, color: Colors.yellowAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sos.namaPendaki ?? 'Pendaki',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    sos.tipePemicu == AppConstants.sosFallDetection ? 'Jatuh Terdeteksi' : 'Pemicu Manual',
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'GPS: ${sos.koordinatLat.toStringAsFixed(5)}, ${sos.koordinatLong.toStringAsFixed(5)}',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: '${sos.koordinatLat}, ${sos.koordinatLong}'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Koordinat disalin ke clipboard')),
                                      );
                                    },
                                    child: const Icon(Icons.copy, size: 16, color: Colors.white70),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _resolveSOS(sos.id),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Tandai Sudah Ditangani / Evakuasi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppTheme.dangerRed,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Stat Cards
              Row(
                children: [
                  Expanded(
                    child: _statCard('Pendaki di Jalur', _activeHikers.toString(), Icons.hiking, AppTheme.skyBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _statCard('Sinyal SOS', _activeSOS.toString(), Icons.sos, AppTheme.dangerRed),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Actions
              const Text('Operasional Basecamp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _actionCard(
                'Verifikasi Tiket Simaksi',
                'Pindai atau masukkan hash tiket pendaki saat check-in',
                Icons.qr_code_scanner,
                AppTheme.primaryGreen,
                () => Navigator.pushNamed(context, AppRoutes.ticketVerify).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Monitor Pendaki di Jalur',
                'Pantau rombongan yang sedang beraktivitas di gunung Anda',
                Icons.radar,
                AppTheme.accentOrange,
                () => Navigator.pushNamed(context, AppRoutes.hikerMonitor).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Update Status Jalur',
                'Ubah status Buka/Tutup/Waspada untuk ${_mountain?.namaGunung ?? 'Gunung'}',
                Icons.edit_road,
                AppTheme.mistGrey,
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Jalur ${_mountain?.namaGunung ?? ''} saat ini: ${_mountain?.statusJalur ?? 'Buka'}')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
