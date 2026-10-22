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
import '../../services/basecamp_alert_service.dart';

class BasecampDashboardScreen extends StatefulWidget {
  const BasecampDashboardScreen({super.key});

  @override
  State<BasecampDashboardScreen> createState() => _BasecampDashboardScreenState();
}

class _BasecampDashboardScreenState extends State<BasecampDashboardScreen> {
  int _activeSOS = 0;
  int _activeHikers = 0;
  int _activePermitsCount = 0;
  List<SosIncident> _activeSosList = [];
  BasecampPost? _basecampPost;
  Mountain? _mountain;
  Timer? _pollingTimer;
  final Set<String> _knownSosIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    BasecampAlertService.instance.addListener(_onAlertServiceUpdate);
    BasecampAlertService.instance.requestIgnoreBatteryOptimizations();
    // Polling setiap 5 detik untuk sinkronisasi cadangan
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadData(silent: true));
  }

  void _onAlertServiceUpdate() {
    if (mounted) {
      _loadData(silent: true);
    }
  }

  @override
  void dispose() {
    BasecampAlertService.instance.removeListener(_onAlertServiceUpdate);
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // Selalu ambil data pos basecamp terbaru dari database lokal / remote
    BasecampPost? post = await DatabaseService.instance.getBasecampByUserId(user.id);
    if (post == null && SupabaseService.instance.isInitialized) {
      post = await SupabaseService.instance.getBasecampByUserId(user.id);
      if (post != null) {
        await DatabaseService.instance.insertBasecampPost(post);
      }
    } else if (post != null && SupabaseService.instance.isInitialized) {
      // Sinkronisasi data basecamp dari Supabase secara realtime
      try {
        final remotePost = await SupabaseService.instance.getBasecampByUserId(user.id);
        if (remotePost != null) {
          post = remotePost;
          await DatabaseService.instance.insertBasecampPost(remotePost);
        }
      } catch (_) {}
    }
    
    final gunungId = user.gunungId ?? post?.gunungId ?? 'mtn-001';
    Mountain? mtn = _mountain;
    mtn ??= await DatabaseService.instance.getMountainById(gunungId);

    // Pastikan monitoring latar belakang aktif untuk pos basecamp ini
    if (!BasecampAlertService.instance.isMonitoring) {
      BasecampAlertService.instance.startMonitoring(
        user: user,
        post: post,
        mountainName: mtn?.namaGunung,
      );
    }

    // Jika online, tarik insiden SOS aktif dan data permit terbaru dari Supabase
    if (SupabaseService.instance.isInitialized) {
      try {
        final remoteSos = await SupabaseService.instance.getActiveSOSIncidents();
        for (final inc in remoteSos) {
          await DatabaseService.instance.insertSosIncident(inc);
        }
        final remotePermits = await SupabaseService.instance.getAllPermits();
        for (final p in remotePermits) {
          await DatabaseService.instance.insertPermit(p);
        }
      } catch (e) {
        debugPrint('⚠️ Gagal pull realtime SOS/Permits dari Supabase: $e');
      }
    }

    // Ambil SOS hanya untuk gunung & basecamp ini (atau SOS darurat umum)
    final sosList = await DatabaseService.instance.getActiveSOSIncidentsForBasecamp(
      gunungId: gunungId,
      basecampId: post?.id,
    );

    // Ambil izin pendaki di jalur khusus gunung & basecamp ini
    final permits = await DatabaseService.instance.getActivePermitsForBasecamp(
      gunungId: gunungId,
      basecampId: post?.id,
    );

    // Hitung total orang (pendaki) di jalur: per orang bukan per rombongan
    final int totalHikersCount = permits.fold<int>(0, (sum, p) => sum + p.jumlahAnggota);

    // Deteksi SOS baru untuk memicu alarm / notifikasi lokal di perangkat petugas
    for (final inc in sosList) {
      if (!_knownSosIds.contains(inc.id)) {
        _knownSosIds.add(inc.id);
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        await NotificationService.instance.showSOSNotification(
          title: '🚨 DARURAT PENDAKI DI ${mtn?.namaGunung.toUpperCase() ?? 'JALUR'}!',
          body: 'Pendaki ${inc.namaPendaki ?? 'Anonim'} mengirim sinyal SOS di koordinat (${inc.koordinatLat.toStringAsFixed(4)}, ${inc.koordinatLong.toStringAsFixed(4)})!',
          payload: 'basecamp_sos',
        );
      }
    }

    if (mounted) {
      setState(() {
        _basecampPost = post;
        _mountain = mtn;
        _activeSosList = sosList;
        _activeSOS = sosList.length;
        _activeHikers = totalHikersCount;
        _activePermitsCount = permits.length;
      });
    }
  }

  Future<void> _resolveSOS(String sosId) async {
    await DatabaseService.instance.updateSOSStatus(sosId, AppConstants.sosHandled);
    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.updateSosStatus(sosId, AppConstants.sosHandled);
    }
    await BasecampAlertService.instance.checkNewSOS();
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
              await _loadData();
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.safeGreen.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppTheme.safeGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Radar Siaga Background Aktif',
                                style: TextStyle(fontSize: 10, color: AppTheme.safeGreen, fontWeight: FontWeight.bold),
                              ),
                            ],
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

              // Stat Cards (Real-time per basecamp)
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Pendaki di Jalur',
                      '$_activeHikers Orang',
                      Icons.hiking,
                      AppTheme.skyBlue,
                      subtitle: '$_activePermitsCount Rombongan',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      'Sisa Kuota Hari Ini',
                      '${_basecampPost?.sisaKuotaHariIni ?? 0} Orang',
                      Icons.people_alt,
                      AppTheme.accentOrange,
                      subtitle: 'Kapasitas: ${_basecampPost?.kuotaHarian ?? 100}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Status Jalur',
                      _basecampPost?.statusJalur ?? 'Buka',
                      _basecampPost?.isBuka == true ? Icons.check_circle_outline : Icons.cancel_outlined,
                      _basecampPost?.isBuka == true ? AppTheme.safeGreen : AppTheme.dangerRed,
                      subtitle: _basecampPost?.isBuka == true ? 'Jalur Dibuka' : 'Jalur Ditutup',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      'Tarif SIMAKSI',
                      'Rp ${(_basecampPost?.hargaSimaksi ?? 15000).toInt()}',
                      Icons.payments_outlined,
                      AppTheme.primaryGreen,
                      subtitle: 'per orang',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Actions
              const Text('Operasional Basecamp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _actionCard(
                'Verifikasi Tiket Simaksi',
                'Pindai QR check-in pendaki & kurangi kuota otomatis secara realtime',
                Icons.qr_code_scanner,
                AppTheme.primaryGreen,
                () => Navigator.pushNamed(context, AppRoutes.ticketVerify).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Monitor Pendaki di Jalur',
                'Pantau seluruh pendaki ($_activeHikers orang) yang sedang aktif di jalur',
                Icons.radar,
                AppTheme.skyBlue,
                () => Navigator.pushNamed(context, AppRoutes.hikerMonitor).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Pengaturan Jalur & SIMAKSI',
                'Atur status Buka/Tutup, kuota harian, sisa kuota, dan tarif SIMAKSI basecamp',
                Icons.tune,
                AppTheme.accentOrange,
                _showBasecampSettingsModal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 22),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w500),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showBasecampSettingsModal() {
    if (_basecampPost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data basecamp belum siap')),
      );
      return;
    }

    final post = _basecampPost!;
    final messenger = ScaffoldMessenger.of(context);
    String selectedStatus = post.statusJalur;
    final kuotaCtrl = TextEditingController(text: post.kuotaHarian.toString());
    final sisaKuotaCtrl = TextEditingController(text: post.sisaKuotaHariIni.toString());
    final hargaCtrl = TextEditingController(text: post.hargaSimaksi.toInt().toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune, color: AppTheme.accentOrange, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pengaturan Jalur & SIMAKSI',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                post.namaPos,
                                style: const TextStyle(fontSize: 12, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Colors.white12),

                    // Status Jalur (Buka / Tutup)
                    const Text(
                      'Status Jalur Basecamp',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedStatus = 'Buka'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedStatus.toLowerCase() == 'buka'
                                    ? AppTheme.safeGreen.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedStatus.toLowerCase() == 'buka' ? AppTheme.safeGreen : Colors.white12,
                                  width: selectedStatus.toLowerCase() == 'buka' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 18,
                                      color: selectedStatus.toLowerCase() == 'buka' ? AppTheme.safeGreen : Colors.white38),
                                  const SizedBox(width: 8),
                                  Text(
                                    'JALUR BUKA',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: selectedStatus.toLowerCase() == 'buka' ? AppTheme.safeGreen : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedStatus = 'Tutup'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedStatus.toLowerCase() == 'tutup'
                                    ? AppTheme.dangerRed.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedStatus.toLowerCase() == 'tutup' ? AppTheme.dangerRed : Colors.white12,
                                  width: selectedStatus.toLowerCase() == 'tutup' ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cancel,
                                      size: 18,
                                      color: selectedStatus.toLowerCase() == 'tutup' ? AppTheme.dangerRed : Colors.white38),
                                  const SizedBox(width: 8),
                                  Text(
                                    'JALUR TUTUP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: selectedStatus.toLowerCase() == 'tutup' ? AppTheme.dangerRed : Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Harga Tiket SIMAKSI
                    const Text(
                      'Harga Tiket SIMAKSI (per Orang)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hargaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                        hintText: 'Contoh: 15000',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Kuota Harian & Sisa Kuota
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kuota Harian (Total)',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: kuotaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  suffixText: 'Orang',
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sisa Kuota Hari Ini',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: sisaKuotaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  suffixText: 'Orang',
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            sisaKuotaCtrl.text = kuotaCtrl.text;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: AppTheme.skyBlue),
                        label: const Text('Reset Sisa Kuota ke Penuh', style: TextStyle(fontSize: 12, color: AppTheme.skyBlue)),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Simpan Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final kuota = int.tryParse(kuotaCtrl.text.trim()) ?? 100;
                                final sisa = int.tryParse(sisaKuotaCtrl.text.trim()) ?? kuota;
                                final harga = double.tryParse(hargaCtrl.text.trim()) ?? 15000.0;

                                setModalState(() => isSaving = true);

                                await DatabaseService.instance.updateBasecampSettings(
                                  basecampId: post.id,
                                  statusJalur: selectedStatus,
                                  kuotaHarian: kuota,
                                  sisaKuotaHariIni: sisa,
                                  hargaSimaksi: harga,
                                );

                                if (SupabaseService.instance.isInitialized) {
                                  await SupabaseService.instance.updateBasecampSettings(
                                    basecampId: post.id,
                                    statusJalur: selectedStatus,
                                    kuotaHarian: kuota,
                                    sisaKuotaHariIni: sisa,
                                    hargaSimaksi: harga,
                                  );
                                }

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  await _loadData();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Pengaturan operasional basecamp berhasil disimpan! ✓'),
                                      backgroundColor: AppTheme.safeGreen,
                                    ),
                                  );
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.save),
                        label: Text(isSaving ? 'Menyimpan...' : 'Simpan Pengaturan Basecamp'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
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
