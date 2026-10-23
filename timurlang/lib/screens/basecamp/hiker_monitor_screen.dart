// ============================================
// TimurLang - Hiker Monitor Screen
// Aura Travel Design System
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/simaksi_permit.dart';
import '../../models/user_personal_data.dart';
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
                                const SizedBox(height: 12),

                                // Tombol Masuk ke Detail Identitas Rombongan
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showGroupDetailsModal(p, leaderName),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySubtle,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.primary.withValues(alpha: 0.25),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.badge_outlined,
                                              color: AppTheme.primary,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Detail Identitas Rombongan',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  'Lihat nama lengkap, alamat & no. darurat',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 11,
                                                    color: AppTheme.textSecondary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            color: AppTheme.primary,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

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

  /// Menampilkan modal rincian identitas pendaki dan seluruh anggota rombongan
  Future<void> _showGroupDetailsModal(SimaksiPermit permit, String fallbackLeaderName) async {
    HapticFeedback.lightImpact();

    // Muat data personal ketua (jika ada) sebagai profil pelengkap
    UserPersonalData? personalData;
    try {
      personalData = await DatabaseService.instance.getPersonalData(permit.userId);
    } catch (_) {}

    if (!mounted) return;

    final members = permit.members;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySubtle,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.badge_outlined, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Identitas Lengkap Rombongan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${permit.namaGunung ?? permit.gunungId} • ${permit.jumlahAnggota} Anggota Rombongan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 22),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.border),

                  // Member List
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        // Metadata ringkas tiket
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _metaItem('Status', 'Di Jalur', AppTheme.accentOrange),
                              Container(width: 1, height: 28, color: AppTheme.border),
                              _metaItem('Tgl Naik', permit.tanggalNaik.toString().substring(0, 10), AppTheme.textPrimary),
                              Container(width: 1, height: 28, color: AppTheme.border),
                              _metaItem('Rombongan', '${permit.jumlahAnggota} Orang', AppTheme.primary),
                            ],
                          ),
                        ),

                        // Render Cards untuk setiap anggota
                        ..._buildMemberListWidgets(
                          permit: permit,
                          members: members,
                          personalData: personalData,
                          fallbackLeaderName: fallbackLeaderName,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildMemberListWidgets({
    required SimaksiPermit permit,
    required List<MemberInfo> members,
    required UserPersonalData? personalData,
    required String fallbackLeaderName,
  }) {
    final List<Widget> widgets = [];

    if (members.isNotEmpty) {
      for (int i = 0; i < members.length; i++) {
        final m = members[i];
        final bool isKetua = m.isKetua || i == 0;
        final String role = isKetua ? 'Ketua Rombongan' : 'Anggota ${i + 1}';

        // 1. Nama Lengkap
        String nama = m.nama.trim();
        if (nama.isEmpty) {
          nama = isKetua ? (personalData?.namaGabungan ?? fallbackLeaderName) : 'Anggota ${i + 1}';
        }

        // 2. Alamat Lengkap
        String alamat = m.alamat.trim();
        if (alamat.isEmpty || alamat == 'Sesuai Profil Pengguna') {
          if (personalData != null && personalData.alamat.trim().isNotEmpty) {
            alamat = [
              personalData.alamat.trim(),
              if (personalData.kelurahan.trim().isNotEmpty) 'Kel. ${personalData.kelurahan.trim()}',
              if (personalData.kecamatan.trim().isNotEmpty) 'Kec. ${personalData.kecamatan.trim()}',
              if (personalData.kotaKabupaten.trim().isNotEmpty) personalData.kotaKabupaten.trim(),
              if (personalData.provinsi.trim().isNotEmpty) personalData.provinsi.trim(),
            ].join(', ');
          } else {
            alamat = isKetua ? 'Alamat belum dilengkapi di profil' : 'Mengikuti domisili ketua rombongan';
          }
        }

        // 3. Nomor Darurat
        String nomorDarurat = m.kontakDarurat.trim();
        if (nomorDarurat.isEmpty || nomorDarurat == '-') {
          if (personalData != null && personalData.noTeleponDarurat.trim().isNotEmpty) {
            nomorDarurat = personalData.noTeleponDarurat.trim();
          } else {
            nomorDarurat = isKetua ? 'Belum dicantumkan' : 'Mengikuti kontak darurat ketua';
          }
        }

        // 4. Nomor Telepon & KTP (jika tersedia)
        String? noTelepon = m.noTelepon?.trim();
        if (noTelepon == null || noTelepon.isEmpty || noTelepon == '-') {
          if (isKetua && personalData != null && personalData.noTelepon.trim().isNotEmpty) {
            noTelepon = personalData.noTelepon.trim();
          }
        }

        String? noKtp = m.noKtp?.trim();
        if (noKtp == null || noKtp.isEmpty || noKtp == '-') {
          if (isKetua && personalData != null && personalData.nomorKtp.trim().isNotEmpty) {
            noKtp = personalData.nomorKtp.trim();
          }
        }

        widgets.add(
          _memberCard(
            role: role,
            isKetua: isKetua,
            nama: nama,
            alamat: alamat,
            nomorDarurat: nomorDarurat,
            noTelepon: noTelepon,
            noKtp: noKtp,
          ),
        );
      }
    } else {
      // Data rombongan tanpa JSON data_anggota terpisah (fallback)
      final String namaKetua = personalData?.namaGabungan ?? fallbackLeaderName;
      String alamatKetua = 'Belum dicantumkan';
      if (personalData != null && personalData.alamat.trim().isNotEmpty) {
        alamatKetua = [
          personalData.alamat.trim(),
          if (personalData.kelurahan.trim().isNotEmpty) 'Kel. ${personalData.kelurahan.trim()}',
          if (personalData.kecamatan.trim().isNotEmpty) 'Kec. ${personalData.kecamatan.trim()}',
          if (personalData.kotaKabupaten.trim().isNotEmpty) personalData.kotaKabupaten.trim(),
          if (personalData.provinsi.trim().isNotEmpty) personalData.provinsi.trim(),
        ].join(', ');
      }
      final String noDaruratKetua = personalData?.noTeleponDarurat.trim().isNotEmpty == true
          ? personalData!.noTeleponDarurat.trim()
          : 'Belum dicantumkan';

      widgets.add(
        _memberCard(
          role: 'Ketua Rombongan',
          isKetua: true,
          nama: namaKetua,
          alamat: alamatKetua,
          nomorDarurat: noDaruratKetua,
          noTelepon: personalData?.noTelepon,
          noKtp: personalData?.nomorKtp,
        ),
      );

      if (permit.jumlahAnggota > 1) {
        for (int i = 1; i < permit.jumlahAnggota; i++) {
          widgets.add(
            _memberCard(
              role: 'Anggota ${i + 1}',
              isKetua: false,
              nama: 'Anggota ${i + 1}',
              alamat: alamatKetua != 'Belum dicantumkan'
                  ? alamatKetua
                  : 'Mengikuti domisili ketua rombongan',
              nomorDarurat: noDaruratKetua,
            ),
          );
        }
      }
    }

    return widgets;
  }

  Widget _memberCard({
    required String role,
    required bool isKetua,
    required String nama,
    required String alamat,
    required String nomorDarurat,
    String? noTelepon,
    String? noKtp,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isKetua ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.border,
          width: isKetua ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Badge & Avatar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isKetua ? AppTheme.primarySubtle : AppTheme.surfaceSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isKetua ? Icons.verified_user_rounded : Icons.person_rounded,
                  color: isKetua ? AppTheme.primary : AppTheme.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isKetua
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isKetua
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isKetua ? AppTheme.primary : AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nama,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppTheme.border),

          // Detail 1: Nama Lengkap
          _memberDetailRow(
            icon: Icons.badge_outlined,
            label: 'Nama Lengkap',
            value: nama,
          ),
          const SizedBox(height: 10),

          // Detail 2: Alamat
          _memberDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Alamat',
            value: alamat,
          ),
          const SizedBox(height: 10),

          // Detail 3: Nomor Darurat (dengan highlight & tombol salin)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nomor Darurat',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        nomorDarurat,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
                if (nomorDarurat.isNotEmpty &&
                    nomorDarurat != '-' &&
                    nomorDarurat != 'Belum dicantumkan')
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: nomorDarurat));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Nomor darurat $nomorDarurat disalin'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
                    tooltip: 'Salin Nomor Darurat',
                    icon: const Icon(Icons.copy_rounded, color: Color(0xFFDC2626), size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          // Opsional: No. Telepon / HP
          if (noTelepon != null && noTelepon.isNotEmpty && noTelepon != '-') ...[
            const SizedBox(height: 10),
            _memberDetailRow(
              icon: Icons.smartphone_rounded,
              label: 'No. Telepon / HP',
              value: noTelepon,
            ),
          ],

          // Opsional: No. Identitas KTP / NIK
          if (noKtp != null && noKtp.isNotEmpty && noKtp != '-') ...[
            const SizedBox(height: 10),
            _memberDetailRow(
              icon: Icons.credit_card_rounded,
              label: 'No. Identitas (KTP)',
              value: noKtp,
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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
