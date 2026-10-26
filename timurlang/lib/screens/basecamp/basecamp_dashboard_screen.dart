// ============================================
// TimurLang - Basecamp Dashboard Screen
// Aura Travel Design System
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../models/basecamp_post.dart';
import '../../models/mountain.dart';
import '../../models/sos_incident.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/basecamp_alert_service.dart';
import '../../utils/image_helper.dart';
import 'manage_trail_checkpoints_screen.dart';
import 'basecamp_permit_management_screen.dart';

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

    // Pastikan akun petugas basecamp selalu memiliki data BasecampPost yang valid dan siap
    if (post == null) {
      post = await DatabaseService.instance.ensureBasecampPostForUser(user);
      if (SupabaseService.instance.isInitialized) {
        try {
          await SupabaseService.instance.syncBasecampPost(post);
        } catch (_) {}
      }
    }
    
    final gunungId = user.gunungId ?? post.gunungId;
    Mountain? mtn = _mountain;
    mtn ??= await DatabaseService.instance.getMountainById(gunungId);
    if (mtn == null) {
      final allMtns = await DatabaseService.instance.getAllMountains();
      if (allMtns.isNotEmpty) {
        mtn = allMtns.first;
      }
    }

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
      basecampId: post.id,
    );

    // Ambil izin pendaki di jalur khusus gunung & basecamp ini
    final permits = await DatabaseService.instance.getActivePermitsForBasecamp(
      gunungId: gunungId,
      basecampId: post.id,
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

  /// Pull-to-refresh: Sinkron otomatis data dua arah (Supabase & SQLite) & muat ulang dashboard
  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    // 1. Eksekusi Sinkronisasi Data Dua Arah
    final syncResult = await SyncService.instance.syncAll();

    // 2. Refresh data pos basecamp, permit pendaki, dan insiden SOS
    await _loadData();

    if (!mounted) return;

    // 3. Feedback notifikasi sinkronisasi mengambang seperti akun pendaki
    final isSuccess = syncResult.failed == 0;
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
                  color: Colors.white,
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

  Future<void> _resolveSOS(String sosId) async {
    await DatabaseService.instance.updateSOSStatus(sosId, AppConstants.sosHandled);
    if (SupabaseService.instance.isInitialized) {
      await SupabaseService.instance.updateSosStatus(sosId, AppConstants.sosHandled);
    }
    await BasecampAlertService.instance.checkNewSOS();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status darurat ditandai: DITANGANI', style: GoogleFonts.plusJakartaSans()),
        backgroundColor: AppTheme.success,
      ),
    );
    _loadData();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Keluar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        content: Text('Apakah Anda yakin ingin keluar dari akun Basecamp?', style: GoogleFonts.plusJakartaSans()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Dashboard Basecamp',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppTheme.border, height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Card Gunung dengan Foto Asli, Informasi Ketinggian & Petugas
              _buildMountainHeroCard(user, displayBasecampName, displayMountainName),
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
                        color: AppTheme.error.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PERINGATAN DARURAT AKTIF!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '$_activeSOS pendaki di jalur membunyikan sinyal darurat!',
                                  style: GoogleFonts.plusJakartaSans(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
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
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_pin_circle, color: Color(0xFFFDE047), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sos.namaPendaki ?? 'Pendaki',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    sos.tipePemicu == AppConstants.sosFallDetection ? 'Jatuh Terdeteksi' : 'Pemicu Manual',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'GPS: ${sos.koordinatLat.toStringAsFixed(5)}, ${sos.koordinatLong.toStringAsFixed(5)}',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: '${sos.koordinatLat}, ${sos.koordinatLong}'));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Koordinat disalin ke clipboard', style: GoogleFonts.plusJakartaSans()),
                                        ),
                                      );
                                    },
                                    child: const Icon(Icons.copy, size: 16, color: Colors.white),
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
                                    foregroundColor: AppTheme.error,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    textStyle: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700),
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

              // Stat Cards (Refined Artisan Design System)
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Pendaki di Jalur',
                      '$_activeHikers Orang',
                      Icons.hiking_rounded,
                      AppTheme.primary,
                      subtitle: '$_activePermitsCount Rombongan',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Sisa Kuota Hari Ini',
                      '${_basecampPost?.sisaKuotaHariIni ?? 0} Orang',
                      Icons.people_alt_rounded,
                      const Color(0xFF2E6B4E),
                      subtitle: 'Kapasitas ${_basecampPost?.kuotaHarian ?? 100}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Status Jalur',
                      _basecampPost?.statusJalur ?? 'Buka',
                      _basecampPost?.isBuka == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      _basecampPost?.isBuka == true ? const Color(0xFF15803D) : AppTheme.error,
                      subtitle: _basecampPost?.isBuka == true ? 'Jalur Dibuka' : 'Jalur Ditutup',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      'Tarif SIMAKSI',
                      'Rp ${(_basecampPost?.hargaSimaksi ?? 15000).toInt()}',
                      Icons.payments_rounded,
                      const Color(0xFF334155),
                      subtitle: 'per orang',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Actions
              Text(
                'Operasional Basecamp',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Verifikasi Tiket Simaksi',
                'Pindai QR check-in pendaki & kurangi kuota otomatis secara realtime',
                Icons.qr_code_scanner,
                AppTheme.primary,
                () => Navigator.pushNamed(context, AppRoutes.ticketVerify).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Monitor Pendaki di Jalur',
                'Pantau seluruh pendaki ($_activeHikers orang) yang sedang aktif di jalur',
                Icons.radar,
                AppTheme.secondary,
                () => Navigator.pushNamed(context, AppRoutes.hikerMonitor).then((_) => _loadData()),
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Pengaturan Jalur & SIMAKSI',
                'Atur status Buka/Tutup, kuota harian, sisa kuota, dan tarif SIMAKSI basecamp',
                Icons.tune,
                AppTheme.primary,
                _showBasecampSettingsModal,
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Manajemen Reservasi & Pembatalan',
                'Kebijakan resmi pembatalan basecamp (opsi Refund 100% / Reschedule) & transfer pengembalian dana',
                Icons.assignment_late_outlined,
                const Color(0xFFD97706),
                () {
                  if (_basecampPost == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BasecampPermitManagementScreen(
                        basecampPost: _basecampPost!,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              const SizedBox(height: 12),
              _actionCard(
                'Pengaturan Titik Pos Jalur',
                'Input & atur titik checkpoint, shelter, elevasi MDPL, dan sumber air jalur ini',
                Icons.add_location_alt_outlined,
                AppTheme.accentOrange,
                () {
                  if (_basecampPost == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageTrailCheckpointsScreen(
                        basecampPost: _basecampPost!,
                        mountain: _mountain,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (subtitle != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17.5,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showBasecampSettingsModal() async {
    BasecampPost? resolvedPost = _basecampPost;
    if (resolvedPost == null) {
      final user = AuthService.instance.currentUser;
      if (user != null) {
        resolvedPost = await DatabaseService.instance.ensureBasecampPostForUser(user);
        if (mounted) {
          setState(() => _basecampPost = resolvedPost);
        }
      }
    }

    if (resolvedPost == null) {
      await _loadData();
      resolvedPost = _basecampPost;
    }

    if (resolvedPost == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Menyiapkan data basecamp...', style: GoogleFonts.plusJakartaSans()),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (!mounted) return;
    final BasecampPost post = resolvedPost;
    final messenger = ScaffoldMessenger.of(context);
    String selectedStatus = post.statusJalur;
    final kuotaCtrl = TextEditingController(text: post.kuotaHarian.toString());
    final sisaKuotaCtrl = TextEditingController(text: post.sisaKuotaHariIni.toString());
    final hargaCtrl = TextEditingController(text: post.hargaSimaksi.toInt().toString());
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
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
                            color: AppTheme.primarySubtle,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.tune, color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pengaturan Jalur & SIMAKSI',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                post.namaPos,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.border),

                    // Status Jalur (Buka / Tutup)
                    Text(
                      'Status Jalur Basecamp',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
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
                                    ? AppTheme.success.withValues(alpha: 0.12)
                                    : AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedStatus.toLowerCase() == 'buka' ? AppTheme.success : AppTheme.border,
                                  width: selectedStatus.toLowerCase() == 'buka' ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: selectedStatus.toLowerCase() == 'buka' ? AppTheme.success : AppTheme.textSecondary.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'JALUR BUKA',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: selectedStatus.toLowerCase() == 'buka' ? AppTheme.success : AppTheme.textSecondary,
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
                                    ? AppTheme.error.withValues(alpha: 0.12)
                                    : AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedStatus.toLowerCase() == 'tutup' ? AppTheme.error : AppTheme.border,
                                  width: selectedStatus.toLowerCase() == 'tutup' ? 1.8 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cancel,
                                    size: 18,
                                    color: selectedStatus.toLowerCase() == 'tutup' ? AppTheme.error : AppTheme.textSecondary.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'JALUR TUTUP',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: selectedStatus.toLowerCase() == 'tutup' ? AppTheme.error : AppTheme.textSecondary,
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
                    Text(
                      'Harga Tiket SIMAKSI (per Orang)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: hargaCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: GoogleFonts.plusJakartaSans(color: AppTheme.primary, fontWeight: FontWeight.bold),
                        hintText: 'Contoh: 15000',
                        filled: true,
                        fillColor: AppTheme.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                        ),
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
                              Text(
                                'Kuota Harian (Total)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: kuotaCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  suffixText: 'Orang',
                                  filled: true,
                                  fillColor: AppTheme.surfaceSubtle,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                  ),
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
                              Text(
                                'Sisa Kuota Hari Ini',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: sisaKuotaCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.plusJakartaSans(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  suffixText: 'Orang',
                                  filled: true,
                                  fillColor: AppTheme.surfaceSubtle,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Reset Sisa Kuota ke Penuh (Secondary Button)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            sisaKuotaCtrl.text = kuotaCtrl.text;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Reset Sisa Kuota ke Penuh',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

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
                                    SnackBar(
                                      content: Text(
                                        'Pengaturan operasional basecamp berhasil disimpan!',
                                        style: GoogleFonts.plusJakartaSans(),
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save, size: 18),
                        label: Text(
                          isSaving ? 'Menyimpan...' : 'Simpan Pengaturan Basecamp',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildMountainHeroCard(User? user, String displayBasecampName, String displayMountainName) {
    final imageProvider = ImageHelper.getImageProvider(_mountain?.fotoUrl, displayMountainName) ??
        const AssetImage('assets/images/background_mount.png') as ImageProvider;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Foto Gunung Asli (Cover)
            Positioned.fill(
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.mountainGradient,
                  ),
                  child: const Center(
                    child: Icon(Icons.terrain_rounded, size: 64, color: Colors.white38),
                  ),
                ),
              ),
            ),
            // Multi-stop Vignette & Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // Content Card
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Tags: Elevasi & Radar Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.terrain_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              _mountain != null ? '${_mountain!.elevasiMdpl} mdpl' : 'Wilayah Konservasi',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.success.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Radar Siaga Aktif',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppTheme.success,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 38),
                  // Nama Gunung (Besar & Tegas)
                  Text(
                    displayMountainName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Nama Pos / Basecamp
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.holiday_village_rounded, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayBasecampName,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Footer Strip: Petugas & Status Jalur Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 15, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Petugas: ${user?.namaLengkap ?? 'Pengelola'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_basecampPost?.isBuka ?? true)
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: ((_basecampPost?.isBuka ?? true)
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626))
                                    .withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                (_basecampPost?.isBuka ?? true) ? 'JALUR BUKA' : 'JALUR TUTUP',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
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
          ],
        ),
      ),
    );
  }
}
