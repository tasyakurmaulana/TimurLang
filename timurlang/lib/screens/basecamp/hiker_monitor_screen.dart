// ============================================
// TimurLang - Hiker Monitor Screen
// Aura Travel Design System
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/simaksi_permit.dart';
import '../../models/basecamp_post.dart';
import '../../services/auth_service.dart';
import '../../services/blockchain_service.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';

class HikerMonitorScreen extends StatefulWidget {
  const HikerMonitorScreen({super.key});

  @override
  State<HikerMonitorScreen> createState() => _HikerMonitorScreenState();
}

class _HikerMonitorScreenState extends State<HikerMonitorScreen> {
  List<SimaksiPermit> _activeHikers = [];
  final Map<String, String> _leaderNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _resolveLeaderNames(List<SimaksiPermit> permits) async {
    for (final p in permits) {
      if (_leaderNames.containsKey(p.id)) continue;
      String? name;
      // 1. Cek dari daftar anggota rombongan
      if (p.members.isNotEmpty) {
        final ketua = p.members.firstWhere(
          (m) => m.isKetua,
          orElse: () => p.members.first,
        );
        if (ketua.nama.trim().isNotEmpty) {
          name = ketua.nama.trim();
        }
      }
      // 2. Cek dari database user jika belum ada nama di dataAnggota
      if (name == null || name.isEmpty) {
        try {
          final u = await DatabaseService.instance.getUserById(p.userId);
          if (u != null && u.namaLengkap.trim().isNotEmpty) {
            name = u.namaLengkap.trim();
          } else if (SupabaseService.instance.isInitialized) {
            final su = await SupabaseService.instance.getUserById(p.userId);
            if (su != null && su.namaLengkap.trim().isNotEmpty) {
              name = su.namaLengkap.trim();
            }
          }
        } catch (_) {}
      }
      _leaderNames[p.id] = name ?? 'Ketua Pendaki';
    }
  }

  Future<void> _loadData() async {
    // Tarik permit terbaru dari server Supabase jika online
    if (SupabaseService.instance.isInitialized) {
      try {
        final remotePermits = await SupabaseService.instance.getAllPermits();
        for (final p in remotePermits) {
          await DatabaseService.instance.insertPermit(p);
        }
      } catch (_) {}
    }

    final user = AuthService.instance.currentUser;
    if (user != null) {
      BasecampPost? post = await DatabaseService.instance.getBasecampByUserId(user.id);
      post ??= await DatabaseService.instance.ensureBasecampPostForUser(user);
      final gunungId = user.gunungId ?? post.gunungId;
      final permits = await DatabaseService.instance.getActivePermitsForBasecamp(
        gunungId: gunungId,
        basecampId: post.id,
      );
      await _resolveLeaderNames(permits);
      if (mounted) {
        setState(() {
          _activeHikers = permits;
          _isLoading = false;
        });
      }
      return;
    }

    final permits = await DatabaseService.instance.getActivePermits();
    final activeList = permits.where((p) => p.statusIzin == 'Di Jalur').toList();
    await _resolveLeaderNames(activeList);
    if (mounted) {
      setState(() {
        _activeHikers = activeList;
        _isLoading = false;
      });
    }
  }

  Future<void> _processCheckOut(String hash) async {
    final res = await BlockchainService.instance.checkOutPermit(hash);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
          backgroundColor: res.success ? AppTheme.success : AppTheme.error,
        ),
      );
      if (res.success) {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalPeople = _activeHikers.fold<int>(0, (sum, p) => sum + p.jumlahAnggota);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Monitor Pendaki',
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _activeHikers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(Icons.hiking, size: 40, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tidak ada rombongan di jalur saat ini',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Banner Total Pendaki
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
                              color: AppTheme.primarySubtle,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.groups_outlined, color: AppTheme.primary, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total: $totalPeople Orang di Jalur',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dari ${_activeHikers.length} rombongan pendaki aktif',
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
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _activeHikers.length,
                        itemBuilder: (context, i) {
                          final p = _activeHikers[i];
                          final leaderName = _leaderNames[p.id] ?? 'Ketua Pendaki';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primarySubtle,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.hiking_rounded, color: AppTheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            leaderName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID User: ${p.userId}',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11.5,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentOrange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Di Jalur',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppTheme.accentOrange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18, color: AppTheme.border),
                                _infoRow('Nama Ketua', leaderName),
                                const SizedBox(height: 6),
                                _infoRow('Gunung', p.namaGunung ?? p.gunungId),
                                const SizedBox(height: 6),
                                _infoRow('Rombongan', '${p.jumlahAnggota} orang'),
                                const SizedBox(height: 6),
                                _infoRow('Tanggal Naik', p.tanggalNaik.toString().substring(0, 10)),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _processCheckOut(p.blockHash),
                                    icon: const Icon(Icons.logout_rounded, size: 16),
                                    label: const Text('Konfirmasi Check-out (Turun)'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.success,
                                      side: BorderSide(color: AppTheme.success.withValues(alpha: 0.35), width: 1.2),
                                      backgroundColor: AppTheme.success.withValues(alpha: 0.08),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      textStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
